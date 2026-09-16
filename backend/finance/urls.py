from django.urls import path, include
from rest_framework.routers import DefaultRouter
from finance.views import ExpenseViewSet, InvoiceViewSet, BakerDashboardView, WithdrawalViewSet

router = DefaultRouter()
router.register(r'expenses', ExpenseViewSet, basename='expense')
router.register(r'invoices', InvoiceViewSet, basename='invoice')
router.register(r'withdrawals', WithdrawalViewSet, basename='withdrawal')

urlpatterns = [
    path('dashboard/', BakerDashboardView.as_view(), name='baker_dashboard'),
    path('', include(router.urls)),
]
