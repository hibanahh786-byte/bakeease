import re

with open('flutter_log.txt', 'r', encoding='utf-8', errors='ignore') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "Null check operator used on a null value" in line or "NoSuchMethodError" in line:
        print(f"--- MATCH AT LINE {i} ---")
        start = max(0, i - 10)
        end = min(len(lines), i + 50)
        for j in range(start, end):
            print(lines[j].strip())
        break
else:
    print("No match found in python script.")
