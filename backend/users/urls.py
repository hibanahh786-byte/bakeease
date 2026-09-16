from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    RegisterView, UserDetailView, BakerProfileView, CustomerProfileView, DeliveryPersonProfileView,
    AdminBakerListView, AdminBakerApproveView, DeliveryPersonListView, AdminUserListView, 
    AdminUserToggleActiveView, AdminComplaintListView, AdminComplaintResolveView, 
    ComplaintCreateView, NotificationViewSet
)
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

router = DefaultRouter()
router.register(r'notifications', NotificationViewSet, basename='notification')

urlpatterns = [
    path('', include(router.urls)),
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('me/', UserDetailView.as_view(), name='user_detail'),
    path('profile/baker/', BakerProfileView.as_view(), name='baker_profile'),
    path('profile/customer/', CustomerProfileView.as_view(), name='customer_profile'),
    path('profile/delivery/', DeliveryPersonProfileView.as_view(), name='delivery_profile'),
    path('admin/bakers/', AdminBakerListView.as_view(), name='admin_baker_list'),
    path('admin/bakers/<int:pk>/approve/', AdminBakerApproveView.as_view(), name='admin_baker_approve'),
    path('delivery_persons/', DeliveryPersonListView.as_view(), name='delivery_person_list'),
    
    # New Admin Routes
    path('admin/users/', AdminUserListView.as_view(), name='admin_user_list'),
    path('admin/users/<int:pk>/toggle_active/', AdminUserToggleActiveView.as_view(), name='admin_user_toggle_active'),
    path('admin/complaints/', AdminComplaintListView.as_view(), name='admin_complaint_list'),
    path('admin/complaints/<int:pk>/resolve/', AdminComplaintResolveView.as_view(), name='admin_complaint_resolve'),
    
    # Support routes
    path('complaints/create/', ComplaintCreateView.as_view(), name='complaint_create'),
]
