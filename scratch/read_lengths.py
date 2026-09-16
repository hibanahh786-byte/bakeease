with open(r'scratch/assets/flutter_assets/kernel_blob.bin', 'rb') as f:
    data = f.read()

FILES = [
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

for f_name in FILES:
    # Match the file URI in the binary
    uri = f"file:///C:/Users/HIBANA/OneDrive/Documents/BakeEase/{f_name}".encode()
    pos = data.find(uri)
    if pos != -1:
        end_uri = pos + len(uri)
        next_bytes = data[end_uri:end_uri+20]
        print(f"File: {f_name}")
        print(f"  Hex after URI: {next_bytes.hex(' ')}")
        # Print the first few chars of source
        # Let's find where 'import' starts
        import_pos = data.find(b'import', end_uri)
        if import_pos != -1 and import_pos - end_uri < 20:
            print(f"  Prefix bytes: {data[end_uri:import_pos].hex(' ')}")
            print(f"  First line: {data[import_pos:import_pos+50].decode(errors='ignore').strip()}")
    else:
        print(f"File {f_name} NOT found in binary.")
