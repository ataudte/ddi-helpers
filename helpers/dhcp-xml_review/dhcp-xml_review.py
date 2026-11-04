#!/usr/bin/env python3

# This script parses a Microsoft DHCP XML export and generates prefixed CSV files for scopes, reservations,
# options and class usage (VendorClass/UserClass). It outputs one CSV per entity with the XML file name as prefix.

import xml.etree.ElementTree as ET
import pandas as pd
import os

def parse_option_values(parent_elem, context_list=None, scope="", ip=""):
    results = {}
    for optval in parent_elem.findall('OptionValues/OptionValue'):
        values = [v.text for v in optval.findall('Value') if v.text]
        opt_id = optval.findtext('OptionId')
        if opt_id:
            results[opt_id] = ', '.join(values)

        if context_list is not None:
            vclass = optval.findtext('VendorClass')
            uclass = optval.findtext('UserClass')
            if vclass:
                context_list.append({
                    'Level': 'Scope' if not ip else 'Reservation',
                    'Scope': scope,
                    'IPAddress': ip,
                    'ClassType': 'VendorClass',
                    'ClassName': vclass,
                    'OptionId': opt_id,
                    'Values': values
                })
            if uclass:
                context_list.append({
                    'Level': 'Scope' if not ip else 'Reservation',
                    'Scope': scope,
                    'IPAddress': ip,
                    'ClassType': 'UserClass',
                    'ClassName': uclass,
                    'OptionId': opt_id,
                    'Values': values
                })

    return results

def sort_option_columns(df):
    meta_cols = [c for c in df.columns if not c.isdigit()]
    option_cols = sorted([c for c in df.columns if c.isdigit()], key=int)
    return df[meta_cols + option_cols]

import os
def parse_dhcp_xml(xml_file_path, output_dir="./"):
    prefix = os.path.splitext(os.path.basename(xml_file_path))[0]

    tree = ET.parse(xml_file_path)
    root = tree.getroot()

    for elem in root.iter():
        if '}' in elem.tag:
            elem.tag = elem.tag.split('}', 1)[1]

    option_rows = []
    scope_rows = []
    reservation_rows = []
    class_usage_rows = []

    # Server-level options
    server_opts = parse_option_values(root.find('./IPv4'))
    option_rows.append({
        'Type': 'global',
        'Scope': '',
        'Name': 'Server',
        **server_opts
    })

    for scope in root.findall('./IPv4/Scopes/Scope'):
        scope_id = scope.findtext('ScopeId')
        subnet_mask = scope.findtext('SubnetMask')
        scope_repr = f"{scope_id}/{subnet_mask}"

        scope_opts = parse_option_values(scope, context_list=class_usage_rows, scope=scope_repr)

        scope_row = {
            'ScopeId': scope_id,
            'Name': scope.findtext('Name'),
            'SubnetMask': subnet_mask,
            'StartRange': scope.findtext('StartRange'),
            'EndRange': scope.findtext('EndRange'),
            'LeaseDuration': scope.findtext('LeaseDuration'),
            'State': scope.findtext('State'),
            'Description': scope.findtext('Description')
        }
        scope_row.update(scope_opts)
        scope_rows.append(scope_row)

        option_rows.append({
            'Type': 'subnet',
            'Scope': scope_repr,
            'Name': scope_id,
            **scope_opts
        })

        for res in scope.findall('./Reservations/Reservation'):
            ip = res.findtext('IPAddress')
            res_opts = parse_option_values(res, context_list=class_usage_rows, scope=scope_repr, ip=ip)
            res_row = {
                'ScopeId': scope_id,
                'IPAddress': ip,
                'ClientId': res.findtext('ClientId'),
                'Name': res.findtext('Name'),
                'Type': res.findtext('Type'),
                'Description': res.findtext('Description')
            }
            res_row.update(res_opts)
            reservation_rows.append(res_row)

            option_rows.append({
                'Type': 'ipAddress',
                'Scope': scope_repr,
                'Name': ip,
                **res_opts
            })

    # Save outputs
    sort_option_columns(pd.DataFrame(option_rows)).to_csv(os.path.join(output_dir, f"{prefix}-options.csv"), index=False)
    sort_option_columns(pd.DataFrame(scope_rows)).to_csv(os.path.join(output_dir, f"{prefix}-scopes.csv"), index=False)
    sort_option_columns(pd.DataFrame(reservation_rows)).to_csv(os.path.join(output_dir, f"{prefix}-reservations.csv"), index=False)

    if class_usage_rows:
        pd.DataFrame(class_usage_rows).to_csv(os.path.join(output_dir, f"{prefix}-classes.csv"), index=False)
    else:
        print("No class assignments found in OptionValues.")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Parse DHCP XML Export to structured CSVs")
    parser.add_argument("xml_file", help="Path to DHCP XML export")
    parser.add_argument("--out", default=".", help="Output directory for CSVs")
    args = parser.parse_args()
    parse_dhcp_xml(args.xml_file, args.out)
