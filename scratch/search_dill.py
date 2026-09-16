with open(r'scratch/assets/flutter_assets/kernel_blob.bin', 'rb') as f:
    data = f.read()

# Let's search for a file path
search_str = b'dashboard_screen.dart'
pos = 0
while True:
    pos = data.find(search_str, pos)
    if pos == -1:
        break
    print(f"Found '{search_str.decode()}' at byte offset: {pos}")
    # Print 200 bytes around the offset
    start = max(0, pos - 100)
    end = min(len(data), pos + 200)
    print(f"Context: {data[start:end]}")
    pos += len(search_str)
