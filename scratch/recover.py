import os
import json
import re

# List of files we need to recover
FILES_TO_RECOVER = [
    'frontend/lib/screens/admin/dashboard_screen.dart',
    'frontend/lib/screens/baker/add_product_screen.dart',
    'frontend/lib/screens/baker/orders_screen.dart',
    'frontend/lib/screens/baker/products_screen.dart',
    'frontend/lib/screens/customer/cakes_screen.dart',
    'frontend/lib/screens/customer/cart_screen.dart',
    'frontend/lib/screens/customer/home_screen.dart',
    'frontend/lib/screens/customer/orders_screen.dart',
    'frontend/lib/screens/customer/product_detail_screen.dart',
    'frontend/lib/screens/customer/wishlist_screen.dart',
]

# Convert to standard normalized paths for matching
FILES_TO_RECOVER_NORM = [os.path.normpath(f).lower() for f in FILES_TO_RECOVER]

brain_dir = r"C:\Users\HIBANA\.gemini\antigravity\brain"

# Dictionary to hold the recovered contents
recovered = {}

print("Scanning historical logs for backups...")

for folder in os.listdir(brain_dir):
    log_dir = os.path.join(brain_dir, folder, ".system_generated", "logs")
    if not os.path.exists(log_dir):
        continue
    
    for log_file in os.listdir(log_dir):
        # Scan transcript.jsonl
        if not log_file.endswith("transcript.jsonl"):
            continue
            
        p = os.path.join(log_dir, log_file)
        try:
            with open(p, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    if not line.strip():
                        continue
                    obj = json.loads(line)
                    # Check if this is a PLANNER_RESPONSE or SYSTEM response containing view_file output
                    content = obj.get("content", "")
                    if not content or "File Path:" not in content or "Showing lines" not in content:
                        continue
                    
                    # Extract file path from content
                    match = re.search(r"File Path:\s*`file:///([^`]+)`", content)
                    if not match:
                        match = re.search(r"File Path:\s*file:///([^\n\r]+)", content)
                    if not match:
                        continue
                        
                    file_path = match.group(1).replace('/', os.sep)
                    norm_path = os.path.normpath(file_path).lower()
                    
                    # Check if this is one of our truncated files
                    matched_file = None
                    for ref in FILES_TO_RECOVER_NORM:
                        if norm_path.endswith(ref):
                            matched_file = ref
                            break
                            
                    if not matched_file:
                        continue
                    
                    # Parse the lines
                    lines = content.split('\n')
                    code_lines = []
                    for l in lines:
                        # Match line formatting like "123: some code"
                        m = re.match(r"^\s*(\d+):\s(.*)$", l)
                        if m:
                            line_num = int(m.group(1))
                            line_content = m.group(2)
                            code_lines.append((line_num, line_content))
                    
                    if not code_lines:
                        continue
                        
                    # Sort by line number
                    code_lines.sort(key=lambda x: x[0])
                    
                    # Check if this is a complete or larger representation than we have
                    total_lines = len(code_lines)
                    
                    # Check if there's a header like "Total Lines: 450"
                    total_lines_match = re.search(r"Total Lines:\s*(\d+)", content)
                    is_complete = False
                    if total_lines_match:
                        expected_lines = int(total_lines_match.group(1))
                        if total_lines >= expected_lines:
                            is_complete = True
                    
                    # Reconstruct content
                    reconstructed = []
                    for idx, (num, val) in enumerate(code_lines):
                        reconstructed.append(val)
                    
                    full_content = '\n'.join(reconstructed)
                    
                    # Store if we have a better/newer version
                    current = recovered.get(matched_file)
                    if not current or (is_complete and not current[2]) or (total_lines > current[0]):
                        recovered[matched_file] = (total_lines, full_content, is_complete, p)
        except Exception as e:
            pass

print("\nRecovery Summary:")
for ref in FILES_TO_RECOVER:
    ref_norm = os.path.normpath(ref).lower()
    if ref_norm in recovered:
        lines, content, is_complete, log_src = recovered[ref_norm]
        status = "COMPLETE" if is_complete else "PARTIAL"
        print(f"[{status}] {ref} - Recovered {lines} lines from {os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(log_src))))}")
        
        # Write back to file
        target_path = os.path.join(r"c:\Users\HIBANA\OneDrive\Documents\BakeEase", ref)
        os.makedirs(os.path.dirname(target_path), exist_ok=True)
        # Apply the IP update from 172.20.10.3 to 172.20.10.6 dynamically during recovery
        updated_content = content.replace('172.20.10.3', '172.20.10.6')
        with open(target_path, 'w', encoding='utf-8') as out_f:
            out_f.write(updated_content)
        print(f"  -> Written to {target_path}")
    else:
        print(f"[FAILED] {ref} - No backup found in logs.")
