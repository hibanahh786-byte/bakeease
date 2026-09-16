import re

log_path = r'C:\Users\HIBANA\.gemini\antigravity\brain\53d242e9-5e66-4e05-8c30-674f242a1641\.system_generated\tasks\task-310.log'
with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

# Find the last occurrence of hot restart
restart_markers = list(re.finditer(r"Performing hot restart...", content))
if restart_markers:
    last_marker = restart_markers[-1]
    post_restart_content = content[last_marker.end():]
    print("=== Post Restart Logs ===")
    print(post_restart_content.strip())
    
    # Check for exceptions
    if "Exception" in post_restart_content or "Error" in post_restart_content or "Exception caught" in post_restart_content.lower():
        print("\n[CRITICAL] Found exception/error post-restart!")
    else:
        print("\n[OK] No errors found post-restart in log.")
else:
    print("No hot restart marker found in logs.")
