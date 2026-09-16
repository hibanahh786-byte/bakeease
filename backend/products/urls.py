from django.urls import path, include
from rest_framework.routers import DefaultRouter
from products.views import CategoryViewSet, ProductViewSet, IngredientViewSet, BakerStockViewSet, ProductIngredientViewSet

router = DefaultRouter()
router.register(r'categories', CategoryViewSet)
router.register(r'items', ProductViewSet)
router.register(r'ingredients', IngredientViewSet)
router.register(r'baker_stock', BakerStockViewSet, basename='baker-stock')
router.register(r'product_ingredients', ProductIngredientViewSet, basename='product-ingredients')

urlpatterns = [
    path('', include(router.urls)),
]
