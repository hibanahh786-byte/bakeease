import os

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

kernel_path = r'scratch/assets/flutter_assets/kernel_blob.bin'
workspace_root = r"c:\Users\HIBANA\OneDrive\Documents\BakeEase"

print(f"Reading kernel binary from {kernel_path}...")
with open(kernel_path, 'rb') as f:
    data = f.read()

def read_varint(data, offset):
    b0 = data[offset]
    if (b0 & 0x80) == 0:
        return b0, 1
    elif (b0 & 0xc0) == 0x80:
        b1 = data[offset + 1]
        val = ((b0 & 0x3f) << 8) | b1
        return val, 2
    elif (b0 & 0xe0) == 0xc0:
        b1 = data[offset + 1]
        b2 = data[offset + 2]
        b3 = data[offset + 3]
        val = ((b0 & 0x1f) << 24) | (b1 << 16) | (b2 << 8) | b3
        return val, 4
    else:
        raise Exception(f"Unsupported varint prefix at offset {offset}: {hex(b0)}")

recovered_count = 0

for ref in FILES_TO_RECOVER:
    # Build URI pattern
    uri = f"file:///C:/Users/HIBANA/OneDrive/Documents/BakeEase/{ref}".encode()
    pos = data.find(uri)
    if pos == -1:
        print(f"[FAILED] {ref} - URI not found in kernel binary.")
        continue
        
    try:
        start_varint = pos + len(uri)
        length, varint_len = read_varint(data, start_varint)
        
        start_source = start_varint + varint_len
        source_bytes = data[start_source:start_source + length]
        
        # Decode source code
        source_code = source_bytes.decode('utf-8', errors='ignore')
        
        # Verify it looks like Dart code
        if not source_code.strip().startswith('import') and not 'class' in source_code:
            print(f"[WARN] {ref} - Extracted content does not look like valid Dart. Skipping.")
            continue
            
        # Write back to workspace
        target_path = os.path.join(workspace_root, ref)
        os.makedirs(os.path.dirname(target_path), exist_ok=True)
        
        # Safely apply the IP address update
        updated_content = source_code.replace('172.20.10.3', '172.20.10.6')
        
        with open(target_path, 'w', encoding='utf-8') as out_f:
            out_f.write(updated_content)
            
        print(f"[SUCCESS] Recovered {ref} ({len(source_code.splitlines())} lines, {length} bytes)")
        recovered_count += 1
        
    except Exception as e:
        print(f"[ERROR] Failed to extract {ref}: {e}")

print(f"\nExtraction completed. Successfully restored {recovered_count} of {len(FILES_TO_RECOVER)} files.")
