from django.urls import path, include
from rest_framework.routers import DefaultRouter
from orders.views import OrderViewSet, CartViewSet, WishlistViewSet, AdminPayoutViewSet

router = DefaultRouter()
router.register(r'list', OrderViewSet, basename='order')
router.register(r'cart', CartViewSet, basename='cart')
router.register(r'wishlist', WishlistViewSet, basename='wishlist')
router.register(r'admin/payouts', AdminPayoutViewSet, basename='admin-payouts')

urlpatterns = [
    path('', include(router.urls)),
]
