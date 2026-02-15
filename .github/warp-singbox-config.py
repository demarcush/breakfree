#!/usr/bin/python

import json
import sys

def update_singbox_config(config_path, private_key_0, private_key_1):
    with open(config_path, 'r') as file:
        config = json.load(file)

    # Update the keys and endpoint in the config
    config['endpoints'][0]['private_key'] = private_key_0
    config['endpoints'][1]['private_key'] = private_key_1

    with open(config_path, 'w') as file:
        json.dump(config, file, sort_keys=True, indent=2)

if __name__ == "__main__":
    config_path = sys.argv[1]
    private_key_0 = sys.argv[2]
    private_key_1 = sys.argv[3]
    update_singbox_config(config_path, private_key_0, private_key_1)
