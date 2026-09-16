import os

backup_dir = os.path.expandvars(r'%APPDATA%\Code\Backups')
for r, d, fs in os.walk(backup_dir):
    for f in fs:
        p = os.path.join(r, f)
        try:
            size = os.path.getsize(p)
            with open(p, 'r', encoding='utf-8', errors='ignore') as file:
                first_line = file.readline().strip()
            print(f"{p}: {size} bytes - {first_line[:100]}")
        except Exception as e:
            print(f"Error reading {p}: {e}")
