import os
import json

history_dir = os.path.expandvars(r'%APPDATA%\Code\User\History')
workspace_root = r"c:\Users\HIBANA\OneDrive\Documents\BakeEase"

print(f"Scanning all resources in VS Code history for 'BakeEase'...")

all_resources = []

for folder in os.listdir(history_dir):
    folder_path = os.path.join(history_dir, folder)
    if not os.path.isdir(folder_path):
        continue
        
    entries_json_path = os.path.join(folder_path, 'entries.json')
    if not os.path.exists(entries_json_path):
        continue
        
    try:
        with open(entries_json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            resource = data.get('resource', '')
            if resource and 'BakeEase' in resource:
                all_resources.append(resource)
    except Exception as e:
        pass

print(f"Found {len(all_resources)} resources matching 'BakeEase':")
for r in sorted(all_resources):
    print(f"  - {r}")
