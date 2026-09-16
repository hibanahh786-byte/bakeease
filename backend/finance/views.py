from rest_framework import viewsets, permissions, views, status
from rest_framework.response import Response
from finance.models import Expense, Invoice
from finance.serializers import ExpenseSerializer, InvoiceSerializer
from orders.models import Order
from django.db.models import Sum, Count, F, Q

class ExpenseViewSet(viewsets.ModelViewSet):
    serializer_class = ExpenseSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if self.request.user.role == 'BAKER' and hasattr(self.request.user, 'baker_profile'):
            if not self.request.user.baker_profile.is_approved:
                return Expense.objects.none()
            return Expense.objects.filter(baker=self.request.user.baker_profile)
        return Expense.objects.none()

    def perform_create(self, serializer):
        if hasattr(self.request.user, 'baker_profile'):
            if not self.request.user.baker_profile.is_approved:
                raise permissions.PermissionDenied("Your baker account is pending admin approval.")
            serializer.save(baker=self.request.user.baker_profile)
        else:
            raise permissions.PermissionDenied("Only Bakers can record expenses.")

class InvoiceViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = InvoiceSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'BAKER' and hasattr(user, 'baker_profile'):
            if not user.baker_profile.is_approved:
                return Invoice.objects.none()
            return Invoice.objects.filter(order__baker=user.baker_profile)
        elif user.role == 'CUSTOMER' and hasattr(user, 'customer_profile'):
            return Invoice.objects.filter(order__customer=user.customer_profile)
        return Invoice.objects.none()

class BakerDashboardView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role != 'BAKER' or not hasattr(user, 'baker_profile'):
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)
        if not user.baker_profile.is_approved:
            return Response({'error': 'Your baker account is pending admin approval.'}, status=status.HTTP_403_FORBIDDEN)
        
        baker = user.baker_profile
        
        from finance.models import Wallet, WithdrawalRequest
        wallet, _ = Wallet.objects.get_or_create(user=user)
        pending_withdrawals = WithdrawalRequest.objects.filter(user=user, status='PENDING').aggregate(total=Sum('amount'))['total'] or 0.0

        # Total Sales (Completed/Delivered Orders)
        total_sales = Order.objects.filter(baker=baker, status='DELIVERED').aggregate(Sum('total_amount'))['total_amount__sum'] or 0.0
        
        # Pending Amount (Accepted Orders not yet marked Delivered/Paid) --- Simplified.
        pending_amount = Order.objects.filter(baker=baker, status='ACCEPTED').aggregate(Sum('total_amount'))['total_amount__sum'] or 0.0

        # Total Expenses
        total_expenses = Expense.objects.filter(baker=baker).aggregate(Sum('amount'))['amount__sum'] or 0.0

        # Profit
        profit = float(total_sales) - float(total_expenses)

        # Total Orders
        total_orders = Order.objects.filter(baker=baker).count()

        # Best Selling Cake
        best_selling = Order.objects.filter(baker=baker).values('items__product__name').annotate(total_sold=Count('items__product')).order_by('-total_sold').first()
        top_cake_name = best_selling['items__product__name'] if best_selling else "None Yet"

        # Expense Breakdown by Category
        category_expenses = Expense.objects.filter(baker=baker).values('category').annotate(total=Sum('amount'))
        expense_breakdown = {item['category']: float(item['total']) for item in category_expenses}
        for cat_code, cat_name in Expense.CATEGORY_CHOICES:
            if cat_code not in expense_breakdown:
                expense_breakdown[cat_code] = 0.0

        # Weekly trend (last 7 days)
        from django.utils import timezone
        import datetime
        today = timezone.now().date()
        last_7_days = [today - datetime.timedelta(days=i) for i in range(6, -1, -1)]
        
        weekly_labels = []
        weekly_sales = []
        weekly_expenses = []
        
        for day in last_7_days:
            weekly_labels.append(day.strftime('%a'))
            day_sales = Order.objects.filter(baker=baker, status='DELIVERED', updated_at__date=day).aggregate(Sum('total_amount'))['total_amount__sum'] or 0.0
            day_expenses = Expense.objects.filter(baker=baker, date_incurred=day).aggregate(Sum('amount'))['amount__sum'] or 0.0
            weekly_sales.append(float(day_sales))
            weekly_expenses.append(float(day_expenses))

        # Delivery Commission (Platform Fee)
        delivery_commission = Order.objects.filter(baker=baker, status='DELIVERED').aggregate(Sum('admin_commission'))['admin_commission__sum'] or 0.0

        # Low Stock Alerts
        from products.models import BakerStock
        low_stock_records = BakerStock.objects.filter(baker=baker).filter(
            Q(quantity__lte=F('low_stock_threshold')) | Q(quantity__lte=1.0)
        )
        low_stock_alerts = [
            {
                'ingredient_name': record.ingredient.name,
                'quantity': float(record.quantity),
                'threshold': float(record.low_stock_threshold),
                'unit': record.ingredient.unit
            }
            for record in low_stock_records
        ]

        # Monthly report (last 4 weeks)
        monthly_labels = []
        monthly_sales = []
        monthly_expenses = []
        
        for w in range(3, -1, -1):
            start_offset = (w + 1) * 7
            end_offset = w * 7
            
            w_start = today - datetime.timedelta(days=start_offset)
            w_end = today - datetime.timedelta(days=end_offset)
            
            if w == 0:
                label = "This Week"
                w_sales = Order.objects.filter(baker=baker, status='DELIVERED', updated_at__date__gte=w_start, updated_at__date__lte=w_end).aggregate(Sum('total_amount'))['total_amount__sum'] or 0.0
                w_expenses = Expense.objects.filter(baker=baker, date_incurred__gte=w_start, date_incurred__lte=w_end).aggregate(Sum('amount'))['amount__sum'] or 0.0
            else:
                label = f"{w}w Ago"
                w_sales = Order.objects.filter(baker=baker, status='DELIVERED', updated_at__date__gte=w_start, updated_at__date__lt=w_end).aggregate(Sum('total_amount'))['total_amount__sum'] or 0.0
                w_expenses = Expense.objects.filter(baker=baker, date_incurred__gte=w_start, date_incurred__lt=w_end).aggregate(Sum('amount'))['amount__sum'] or 0.0
            
            monthly_labels.append(label)
            monthly_sales.append(float(w_sales))
            monthly_expenses.append(float(w_expenses))

        return Response({
            'total_sales': total_sales,
            'amount_received': total_sales, # Assuming delivered = received for simplicity
            'pending_amount': pending_amount,
            'total_expenses': total_expenses,
            'profit': profit,
            'total_orders': total_orders,
            'best_selling_cake': top_cake_name,
            'expense_breakdown': expense_breakdown,
            'weekly_report': {
                'labels': weekly_labels,
                'sales': weekly_sales,
                'expenses': weekly_expenses
            },
            'monthly_report': {
                'labels': monthly_labels,
                'sales': monthly_sales,
                'expenses': monthly_expenses
            },
            'low_stock_alerts': low_stock_alerts,
            'delivery_commission': delivery_commission,
            'wallet_balance': float(wallet.balance),
            'wallet_withdrawn': float(wallet.withdrawn_amount),
            'wallet_pending_withdrawal': float(pending_withdrawals)
        })

from rest_framework.decorators import action
from django.db import transaction
from django.utils import timezone
from finance.models import Wallet, WithdrawalRequest
from finance.serializers import WalletSerializer, WithdrawalRequestSerializer
from users.views import IsAdminUser

class WithdrawalViewSet(viewsets.ModelViewSet):
    serializer_class = WithdrawalRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'ADMIN' or user.is_superuser or getattr(user, 'is_staff', False):
            return WithdrawalRequest.objects.all().order_by('-requested_at')
        elif user.role in ['BAKER', 'DELIVERY_PERSON']:
            return WithdrawalRequest.objects.filter(user=user).order_by('-requested_at')
        return WithdrawalRequest.objects.none()

    def perform_create(self, serializer):
        user = self.request.user
        if user.role not in ['BAKER', 'DELIVERY_PERSON']:
            raise permissions.PermissionDenied("Only Bakers and Delivery Persons can request withdrawals.")
            
        # Check bank details configuration
        bank_name = None
        account_number = None
        ifsc_code = None
        account_holder_name = None
        
        if user.role == 'BAKER' and hasattr(user, 'baker_profile'):
            profile = user.baker_profile
            if not profile.is_approved:
                raise permissions.PermissionDenied("Your baker account is pending admin approval.")
            bank_name = profile.bank_name
            account_number = profile.account_number
            ifsc_code = profile.ifsc_code
            account_holder_name = profile.account_holder_name
        elif user.role == 'DELIVERY_PERSON' and hasattr(user, 'delivery_profile'):
            profile = user.delivery_profile
            bank_name = profile.bank_name
            account_number = profile.account_number
            ifsc_code = profile.ifsc_code
            account_holder_name = profile.account_holder_name
        else:
            raise permissions.PermissionDenied("User profile not found.")
            
        if not all([bank_name, account_number, ifsc_code, account_holder_name]):
            raise serializers.ValidationError("Please configure your registered bank account details before requesting a withdrawal.")

        amount = serializer.validated_data.get('amount')
        if amount <= 0:
            raise serializers.ValidationError("Withdrawal amount must be greater than zero.")

        # Atomic transaction to deduct balance
        with transaction.atomic():
            wallet, _ = Wallet.objects.get_or_create(user=user)
            if wallet.balance < amount:
                raise serializers.ValidationError("Insufficient wallet balance.")
                
            wallet.balance -= amount
            wallet.save()
            
            serializer.save(
                user=user,
                bank_name=bank_name,
                account_number=account_number,
                ifsc_code=ifsc_code,
                account_holder_name=account_holder_name,
                status='PENDING'
            )

    @action(detail=True, methods=['post'], permission_classes=[IsAdminUser])
    def approve(self, request, pk=None):
        withdrawal = self.get_object()
        if withdrawal.status != 'PENDING':
            return Response({'error': 'Only pending withdrawals can be approved.'}, status=status.HTTP_400_BAD_REQUEST)
            
        with transaction.atomic():
            withdrawal.status = 'APPROVED'
            withdrawal.processed_at = timezone.now()
            withdrawal.save()
            
            wallet, _ = Wallet.objects.get_or_create(user=withdrawal.user)
            wallet.withdrawn_amount += withdrawal.amount
            wallet.save()
            
            # Send Notification
            from users.models import Notification
            Notification.objects.create(
                user=withdrawal.user,
                title="Withdrawal Approved",
                message=f"Your withdrawal request of ₹{withdrawal.amount:.2f} has been approved and transferred to your bank account."
            )
            
        return Response({'status': 'Withdrawal approved'})

    @action(detail=True, methods=['post'], permission_classes=[IsAdminUser])
    def reject(self, request, pk=None):
        withdrawal = self.get_object()
        if withdrawal.status != 'PENDING':
            return Response({'error': 'Only pending withdrawals can be rejected.'}, status=status.HTTP_400_BAD_REQUEST)
            
        with transaction.atomic():
            withdrawal.status = 'REJECTED'
            withdrawal.processed_at = timezone.now()
            withdrawal.save()
            
            wallet, _ = Wallet.objects.get_or_create(user=withdrawal.user)
            wallet.balance += withdrawal.amount
            wallet.save()
            
            # Send Notification
            from users.models import Notification
            Notification.objects.create(
                user=withdrawal.user,
                title="Withdrawal Rejected",
                message=f"Your withdrawal request of ₹{withdrawal.amount:.2f} has been rejected. The amount has been refunded to your wallet."
            )
            
        return Response({'status': 'Withdrawal rejected'})
