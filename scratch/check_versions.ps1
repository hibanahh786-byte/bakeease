$shell = New-Object -ComObject Shell.Application
$folder = $shell.Namespace('C:\Users\HIBANA\OneDrive\Documents\BakeEase\frontend\lib\screens\baker')
$item = $folder.ParseName('add_product_screen.dart')
$item.Verbs() | ForEach-Object { $_.Name }
