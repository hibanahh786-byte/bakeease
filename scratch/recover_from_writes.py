import os
import json
import re

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

FILES_TO_RECOVER_NORM = [os.path.normpath(f).lower() for f in FILES_TO_RECOVER]

brain_dir = r"C:\Users\HIBANA\.gemini\antigravity\brain"

recovered = {}

print("Scanning all past session transcripts for file write/replace operations...")

for folder in os.listdir(brain_dir):
    log_dir = os.path.join(brain_dir, folder, ".system_generated", "logs")
    if not os.path.exists(log_dir):
        continue
    
    for log_file in os.listdir(log_dir):
        if not log_file.endswith(".jsonl"):
            continue
            
        p = os.path.join(log_dir, log_file)
        try:
            with open(p, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    if not line.strip():
                        continue
                    obj = json.loads(line)
                    
                    # We are looking for PLANNER_RESPONSE containing tool calls
                    if obj.get("type") != "PLANNER_RESPONSE" or not obj.get("tool_calls"):
                        continue
                    
                    for tc in obj["tool_calls"]:
                        tc_name = tc.get("name", "")
                        args = tc.get("arguments", {})
                        if not args:
                            continue
                            
                        target_file = args.get("TargetFile", "")
                        if not target_file:
                            continue
                            
                        norm_target = os.path.normpath(target_file).lower()
                        
                        # Check if matches any of our target files
                        matched_file = None
                        for ref in FILES_TO_RECOVER_NORM:
                            if norm_target.endswith(ref):
                                matched_file = ref
                                break
                                
                        if not matched_file:
                            continue
                            
                        content = ""
                        op_type = ""
                        
                        if "write_to_file" in tc_name:
                            content = args.get("CodeContent", "")
                            op_type = "write_to_file"
                        elif "replace_file_content" in tc_name:
                            # Sometimes they replace the entire file, check length
                            content = args.get("ReplacementContent", "")
                            op_type = "replace_file_content"
                            
                        if not content:
                            continue
                            
                        total_lines = len(content.split('\n'))
                        
                        # Keep the largest content we find
                        current = recovered.get(matched_file)
                        if not current or total_lines > current[0]:
                            recovered[matched_file] = (total_lines, content, op_type, p)
                            
        except Exception as e:
            pass

print("\nRecovery Results from Writes:")
for ref in FILES_TO_RECOVER:
    ref_norm = os.path.normpath(ref).lower()
    if ref_norm in recovered:
        lines, content, op_type, log_src = recovered[ref_norm]
        print(f"[SUCCESS] {ref} - Recovered {lines} lines via {op_type} from {os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(log_src))))}")
        
        target_path = os.path.join(r"c:\Users\HIBANA\OneDrive\Documents\BakeEase", ref)
        os.makedirs(os.path.dirname(target_path), exist_ok=True)
        # Apply the IP address update
        updated_content = content.replace('172.20.10.3', '172.20.10.6')
        with open(target_path, 'w', encoding='utf-8') as out_f:
            out_f.write(updated_content)
        print(f"  -> Written to {target_path}")
    else:
        print(f"[FAILED] {ref} - No write/replace backup found.")
