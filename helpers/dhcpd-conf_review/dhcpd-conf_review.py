#!/usr/bin/env python3

# This script parses an ISC DHCPD configuration file (dhcpd.conf) and generates
# prefixed CSV files for scopes (subnets/shared-networks), hosts (reservations),
# and options, including the DHCP option number in the column header where available.

import re
import pandas as pd
import os
import argparse

# --- DHCP Option Mapping (Well-Known Options 1-127 + common others) ---
DHCP_OPTION_MAP = {
    # RFC 2132 - DHCP Options and BOOTP Vendor Extensions
    'subnet_mask': '1', 'time_offset': '2', 'routers': '3', 'time_servers': '4', 'name_servers': '5', 'domain_name_servers': '6', 
    'log_servers': '7', 'cookie_servers': '8', 'lpr_servers': '9', 'impress_servers': '10', 'resource_location_servers': '11', 
    'host_name': '12', 'boot_size': '13', 'merit_dump_file': '14', 'domain_name': '15', 'swap_server': '16', 
    'root_path': '17', 'extensions_path': '18', 'ip_forwarding': '19', 'non_local_source_routing': '20', 'policy_filter': '21', 
    'max_datagram_reassembly': '22', 'default_ip_ttl': '23', 'path_mtu_aging_timeout': '24', 'path_mtu_plateau_table': '25', 
    'interface_mtu': '26', 'all_subnets_local': '27', 'broadcast_address': '28', 'perform_mask_discovery': '29', 'mask_supplier': '30', 
    'router_discovery': '31', 'router_solicitation_address': '32', 'static_routes': '33', 'trailer_encapsulation': '34', 
    'arp_cache_timeout': '35', 'ethernet_encapsulation': '36', 'tcp_default_ttl': '37', 'tcp_keepalive_interval': '38', 
    'tcp_keepalive_garbage': '39', 'nis_domain': '40', 'nis_servers': '41', 'ntp_servers': '42', 'vendor_encapsulated_options': '43', 
    'netbios_name_servers': '44', 'netbios_dd_server': '45', 'netbios_node_type': '46', 'netbios_scope': '47', 'x_font_servers': '48', 
    'x_display_manager': '49', 'dhcp_requested_address': '50', 'dhcp_lease_time': '51', 'dhcp_option_overload': '52', 
    'dhcp_message_type': '53', 'dhcp_server_identifier': '54', 'dhcp_parameter_request_list': '55', 'dhcp_message': '56', 
    'dhcp_max_message_size': '57', 'dhcp_renewal_time': '58', 'dhcp_rebinding_time': '59', 'vendor_class_identifier': '60', 
    'dhcp_client_identifier': '61', 'netware_ip_domain': '62', 'netware_ip_option': '63', 'nisplus_domain': '64', 'nisplus_servers': '65', 
    'tftp_server_name': '66', 'bootfile_name': '67', 'mobile_ip_home_agent': '68', 'smtp_server': '69', 'pop3_server': '70', 
    'nntp_server': '71', 'www_server': '72', 'finger_server': '73', 'irc_server': '74', 'street_talk_server': '75', 
    'stda_server': '76', 'user_class': '77', 'slp_directory_agent': '78', 'slp_service_scope': '79', 'dhcp_agent_options': '82', 
    'nds_servers': '85', 'nds_tree_name': '86', 'nds_context': '87', 'bcmcs_controller_domain_name': '88', 
    'bcmcs_controller_ipv4_address': '89', 'authentication': '90', 'client_last_transaction_time': '91', 'associated_ip': '92', 
    'client_system_architecture': '93', 'client_network_interface_identifier': '94', 'ldap_url': '95', 
    'client_machine_identifier': '97', 'geoconf_civic': '99', 'ieee_1003_1_timezone': '100', 'pcode': '101', 'tftp_server_address': '128', 
    'sip_servers': '120', 'classless_static_route': '121', 'cable_labs_encapsulation': '122', 'geoloc': '144', 'fqdn': '81', 
    'pana_agent': '136', 'lost': '137', 'capwap_ac_v4': '138', 'wpad_url': '252',
}


# --- Preprocessing and Core Logic ---

def preprocess_conf(lines):
    """
    Merges multi-line directives and removes comments to simplify parsing.
    """
    processed_lines = []
    buffer = ""
    
    for line in lines:
        line = line.split('#')[0].strip() # Remove comments
        if not line:
            continue
            
        buffer += " " + line
        
        # Check if the line ends a statement
        if line.endswith(';'):
            processed_lines.append(buffer.strip())
            buffer = ""
        elif line.endswith('{') or line.endswith('}'):
            if buffer.strip() != line:
                processed_lines.append(buffer.strip())
            processed_lines.append(line)
            buffer = ""
        
    if buffer.strip():
        processed_lines.append(buffer.strip())

    return processed_lines


def parse_dhcpd_conf(conf_file_path, output_dir="./"):
    """
    Parses a dhcpd.conf file using a state machine on preprocessed lines.
    """
    os.makedirs(output_dir, exist_ok=True)
    prefix = os.path.splitext(os.path.basename(conf_file_path))[0]

    # Data lists to be converted to DataFrames
    option_rows = []
    scope_rows = []
    reservation_rows = []
    
    # State tracking
    current_scope = {}
    current_host = {}
    current_options = {}
    scope_repr = ""
    
    scope_stack = []

    # Regex for key elements
    OPTION_ASSIGNMENT_RE = re.compile(r'^\s*(?P<key>option\s+[a-zA-Z0-9_-]+)\s+(?P<value>[^;]+);')
    OPTION_DEFINITION_RE = re.compile(r'^\s*option\s+[a-zA-Z0-9_-]+\s+code\s+\d+\s+=.*?;')
    DIRECTIVE_RE = re.compile(r'^\s*(?P<key>[a-zA-Z0-9_-]+)\s+(?P<value>[^;]+);')
    START_BLOCK_RE = re.compile(r'^\s*(?P<type>subnet|shared-network|host)\s+(?P<name>[^{]+)\s*{')
    END_BLOCK_RE = re.compile(r'^\s*}')
    
    # Helper to clean up option keys and get the header format: number|name
    def get_option_header(key):
        # 1. Clean the key: 'option domain-name-servers' -> 'domain_name_servers'
        name = key.replace('option ', '').replace('-', '_')
        
        # 2. Look up the number
        number = DHCP_OPTION_MAP.get(name, None)
        
        # 3. Handle ISC-specific option definitions like "option option-101 code 101 = string"
        if not number:
             match_code = re.search(r'option_(\d+)', name)
             if match_code:
                 number = match_code.group(1)
        
        # 4. Format the header
        if number:
            return f"{number}|{name}"
        
        # Fallback for non-mapped, non-standard options
        return name 

    # Helper to finalize and store a record
    def finalize_record(record_type, record, current_opts):
        """Finalizes a record (scope or host) and adds options and tracking data."""
        
        option_entry = {
            'Type': record_type,
            'Scope': record.get('ScopeId', ''),
            'Name': record.get('Name', record.get('IPAddress', 'global'))
        }
        
        # Apply the new header format for options
        cleaned_opts = {}
        for k, v in current_opts.items():
            header = get_option_header(k)
            cleaned_opts[header] = v.strip()
            
        record.update(cleaned_opts)
        option_entry.update(cleaned_opts)

        if record_type == 'global':
            option_rows.append(option_entry)
        elif record_type in ('subnet', 'shared-network'):
            scope_rows.append(record)
            option_entry['Type'] = 'subnet'
            option_rows.append(option_entry)
        elif record_type == 'ipAddress':
            reservation_rows.append(record)
            option_entry['Type'] = 'ipAddress'
            option_rows.append(option_entry)

    with open(conf_file_path, 'r') as f:
        raw_lines = f.readlines()
        
    # --- Preprocess and Global Options Pass ---
    processed_lines = preprocess_conf(raw_lines)

    global_options = {}
    for line in processed_lines:
        m_start = START_BLOCK_RE.match(line)
        if m_start:
            break
        
        # 1. Skip Option Definitions
        if OPTION_DEFINITION_RE.match(line):
            continue
            
        # 2. Only capture Option Assignments
        m_opt_assign = OPTION_ASSIGNMENT_RE.match(line)
        if m_opt_assign:
            global_options[m_opt_assign.group('key')] = m_opt_assign.group('value')
    
    if global_options:
        finalize_record('global', {'Name': 'Server'}, global_options)
    
    # --- Main Scopes and Reservations Pass ---
    
    for line in processed_lines:
        
        # 1. Block Start
        m_start = START_BLOCK_RE.match(line)
        if m_start:
            block_type = m_start.group('type')
            block_name = m_start.group('name').strip()
            
            if block_type in ('subnet', 'shared-network'):
                
                if current_scope:
                    scope_stack.append({'scope': current_scope, 'options': current_options, 'repr': scope_repr})

                current_scope = {'BlockType': block_type, 'ScopeId': '', 'SubnetMask': ''}
                current_options = {}
                
                if block_type == 'subnet':
                    parts = block_name.split('netmask')
                    if len(parts) == 2:
                        current_scope['ScopeId'] = parts[0].strip()
                        current_scope['SubnetMask'] = parts[1].strip()
                        scope_repr = f"{current_scope['ScopeId']}/{current_scope['SubnetMask']}"
                    else:
                        scope_repr = block_name
                        current_scope['ScopeId'] = block_name
                
                elif block_type == 'shared-network':
                    current_scope['ScopeId'] = block_name
                    scope_repr = block_name

                current_scope['Name'] = current_scope['ScopeId']
                current_host = {}

            elif block_type == 'host':
                if current_host:
                    finalize_record('ipAddress', current_host, current_options)

                current_host = {'ScopeId': scope_repr, 'Name': block_name}
                current_options = {}
            
            continue

        # 2. Block End
        m_end = END_BLOCK_RE.match(line)
        if m_end:
            if current_host:
                finalize_record('ipAddress', current_host, current_options)
                current_host = {}
                current_options = scope_stack[-1]['options'] if scope_stack else {} 
                
            elif current_scope:
                finalize_record('subnet', current_scope, current_options) 
                
                if scope_stack:
                    scope_state = scope_stack.pop()
                    current_scope = scope_state['scope']
                    current_options = scope_state['options']
                    scope_repr = scope_state['repr']
                else:
                    current_scope = {}
                    current_options = {}
                    scope_repr = ""
                
            continue

        # 3. Directives/Options
        if not current_scope and not current_host:
            continue
            
        # 3a. Option Assignment
        m_opt = OPTION_ASSIGNMENT_RE.match(line)
        if m_opt:
            key = m_opt.group('key')
            value = m_opt.group('value')
            current_options[key] = value
            continue
            
        # 3b. Ignore Option Definition within a block
        if OPTION_DEFINITION_RE.match(line):
            continue
            
        # 3c. Directives
        m_dir = DIRECTIVE_RE.match(line)
        if m_dir:
            key = m_dir.group('key')
            value = m_dir.group('value')
            value = value.strip().strip('"')

            if current_host:
                if key == 'hardware':
                    current_host['ClientId'] = value.split(' ', 1)[-1].strip()
                elif key == 'fixed-address':
                    current_host['IPAddress'] = value.strip()
                elif key == 'description':
                    current_host['Description'] = value

            elif current_scope:
                if key == 'range':
                    parts = value.split()
                    if len(parts) >= 2:
                        current_scope['StartRange'] = parts[0].strip()
                        current_scope['EndRange'] = parts[-1].strip()
                elif key == 'max-lease-time':
                    current_scope['LeaseDuration'] = value.strip()
                elif key == 'description':
                    current_scope['Description'] = value
                    
    # --- Post-loop Finalization ---
    if current_scope:
        finalize_record('subnet', current_scope, current_options)
        
    while scope_stack:
        scope_state = scope_stack.pop()
        finalize_record('subnet', scope_state['scope'], scope_state['options'])

    # --- Save Outputs ---
    
    def sort_option_columns(df):
        # Sort columns: Meta first, then options sorted by number (if available)
        
        all_meta_keys = ['Type', 'Scope', 'Name', 'ScopeId', 'SubnetMask', 'StartRange', 'EndRange', 'LeaseDuration', 'State', 'Description', 'IPAddress', 'ClientId', 'BlockType']
        meta_cols = [c for c in df.columns if c in all_meta_keys]
        
        option_cols = [c for c in df.columns if c not in meta_cols]
        
        # FIX: Ensure option_sort_key always returns a comparable string
        def option_sort_key(col):
            if '|' in col:
                # Part 1: Option Number, Part 2: Option Name
                parts = col.split('|')
                try:
                    # Return a zero-padded string of the number (e.g., '6' -> '006')
                    num = int(parts[0])
                    return f"{num:03d}" 
                except ValueError:
                    # If the 'number' is a non-numeric string (e.g., 'DDNS'), 
                    # prefix with 'Z' to sort after all numeric options.
                    return f"Z_{parts[0]}|{parts[1]}"
            
            # For columns without the '|' separator (non-mapped directives), 
            # prefix with 'Z' to sort after all numeric options.
            return f"Z_{col}"
            
        sorted_option_cols = sorted(option_cols, key=option_sort_key)
        
        return df[meta_cols + sorted_option_cols]

    if option_rows:
        sort_option_columns(pd.DataFrame(option_rows)).to_csv(os.path.join(output_dir, f"{prefix}-options.csv"), index=False)
    
    if scope_rows:
        df_scopes = pd.DataFrame(scope_rows)
        if 'State' not in df_scopes.columns:
            df_scopes['State'] = 'Active'
        
        sort_option_columns(df_scopes).to_csv(os.path.join(output_dir, f"{prefix}-scopes.csv"), index=False)

    if reservation_rows:
        df_reservations = pd.DataFrame(reservation_rows)
        if 'Type' not in df_reservations.columns:
            df_reservations['Type'] = 'DHCP'
            
        sort_option_columns(df_reservations).to_csv(os.path.join(output_dir, f"{prefix}-reservations.csv"), index=False)

    print(f"Successfully parsed '{conf_file_path}' and generated CSV files in '{output_dir}'.")


# --- Main Execution ---

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Parse ISC DHCPD configuration file (dhcpd.conf) to structured CSVs")
    parser.add_argument("conf_file", help="Path to dhcpd.conf file")
    parser.add_argument("--out", default=".", help="Output directory for CSVs")
    args = parser.parse_args()
    parse_dhcpd_conf(args.conf_file, args.out)