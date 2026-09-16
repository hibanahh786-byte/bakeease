$shell = New-Object -ComObject Shell.Application
$files = @(
    "frontend\lib\screens\admin\dashboard_screen.dart",
    "frontend\lib\screens\baker\add_product_screen.dart",
    "frontend\lib\screens\baker\orders_screen.dart",
    "frontend\lib\screens\baker\products_screen.dart",
    "frontend\lib\screens\customer\cakes_screen.dart",
    "frontend\lib\screens\customer\cart_screen.dart",
    "frontend\lib\screens\customer\home_screen.dart",
    "frontend\lib\screens\customer\orders_screen.dart",
    "frontend\lib\screens\customer\product_detail_screen.dart",
    "frontend\lib\screens\customer\wishlist_screen.dart"
)

foreach ($file in $files) {
    $absPath = Join-Path "C:\Users\HIBANA\OneDrive\Documents\BakeEase" $file
    $dir = Split-Path $absPath
    $name = Split-Path $absPath -Leaf
    
    $folder = $shell.Namespace($dir)
    $item = $folder.ParseName($name)
    
    Write-Host "Opening Previous Versions dialog for: $file"
    # Invoke the 'Restore previous versions' context menu item
    $item.InvokeVerb("Restore previous &versions")
    Start-Sleep -Milliseconds 500
}
