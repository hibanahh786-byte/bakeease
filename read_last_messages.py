import json

transcript_path = r"C:\Users\HIBANA\.gemini\antigravity\brain\f24f1781-df2e-4cc5-a6ed-3a70c80f3f1a\.system_generated\logs\transcript.jsonl"

steps = []
with open(transcript_path, "r", encoding="utf-8") as f:
    for line in f:
        try:
            steps.append(json.loads(line))
        except Exception as e:
            pass

print(f"Total steps: {len(steps)}")
# Let's print steps from 1620 to 1688
for idx in range(1620, min(1688, len(steps))):
    step = steps[idx]
    stype = step.get("type", "")
    source = step.get("source", "")
    content = step.get("content", "") or ""
    tool_calls = step.get("tool_calls", [])
    
    print(f"\nStep {idx} [{source} - {stype}]:")
    if content:
        safe_content = content.encode('ascii', errors='replace').decode('ascii')
        print(safe_content.strip()[:300])
    if tool_calls:
        print(f"Tool calls: {[tc['name'] for tc in tool_calls]}")
    print("-" * 50)
