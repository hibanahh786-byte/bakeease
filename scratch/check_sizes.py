import os

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

for f in FILES:
    path = os.path.join(r"c:\Users\HIBANA\OneDrive\Documents\BakeEase", f)
    size = os.path.getsize(path) if os.path.exists(path) else -1
    print(f"{f}: {size} bytes")
