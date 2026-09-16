import os

FILES_TO_REPLACE = [
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

workspace_root = r"c:\Users\HIBANA\OneDrive\Documents\BakeEase"

print("Starting safe IP address update...")

updated_count = 0

for ref in FILES_TO_REPLACE:
    target_path = os.path.join(workspace_root, ref)
    if not os.path.exists(target_path):
        print(f"[SKIP] {ref} - File does not exist.")
        continue
        
    try:
        # 1. Read the file completely
        with open(target_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
            
        if not content:
            print(f"[WARN] {ref} is empty! Please restore it first.")
            continue
            
        # 2. Check if the old IP is in the content
        if '172.20.10.3' in content:
            # 3. Perform replacement
            updated_content = content.replace('172.20.10.3', '172.20.10.6')
            
            # 4. Write back to the file
            with open(target_path, 'w', encoding='utf-8') as f:
                f.write(updated_content)
            print(f"[SUCCESS] Updated {ref}")
            updated_count += 1
        else:
            print(f"[OK] {ref} already updated or does not contain old IP.")
    except Exception as e:
        print(f"[ERROR] Failed to update {ref}: {e}")

print(f"\nDone. Successfully updated {updated_count} files.")
