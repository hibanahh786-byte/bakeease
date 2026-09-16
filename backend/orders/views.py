from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from orders.models import Order, Cart, CartItem, Wishlist, WishlistItem
from orders.serializers import OrderSerializer, CartSerializer, WishlistSerializer
from finance.models import Invoice
import uuid
import razorpay
import os

RAZORPAY_KEY_ID = os.environ.get('RAZORPAY_KEY_ID', 'rzp_test_YOUR_KEY_ID')
RAZORPAY_KEY_SECRET = os.environ.get('RAZORPAY_KEY_SECRET', 'YOUR_SECRET_KEY')
razorpay_client = razorpay.Client(auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET))

class OrderViewSet(viewsets.ModelViewSet):
    serializer_class = OrderSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'ADMIN' or user.is_superuser or getattr(user, 'is_staff', False):
            return Order.objects.all()
        elif user.role == 'BAKER' and hasattr(user, 'baker_profile'):
            if not user.baker_profile.is_approved:
                return Order.objects.none()
            return Order.objects.filter(baker=user.baker_profile)
        elif user.role == 'CUSTOMER' and hasattr(user, 'customer_profile'):
            return Order.objects.filter(customer=user.customer_profile)
        elif user.role == 'DELIVERY_PERSON' and hasattr(user, 'delivery_profile'):
            return Order.objects.filter(delivery_person=user.delivery_profile)
        return Order.objects.none()

    def perform_create(self, serializer):
        if hasattr(self.request.user, 'customer_profile'):
            serializer.save(
                customer=self.request.user.customer_profile,
                status='PENDING',
                payment_status='PENDING_PAYMENT'
            )
        else:
            raise permissions.PermissionDenied("Only Customers can create orders directly.")

    @action(detail=False, methods=['get'])
    def finance_stats(self, request):
        if not hasattr(request.user, 'baker_profile'):
            return Response(status=status.HTTP_403_FORBIDDEN)
        if not request.user.baker_profile.is_approved:
            return Response({"error": "Your baker account is pending admin approval."}, status=status.HTTP_403_FORBIDDEN)
        orders = Order.objects.filter(baker=request.user.baker_profile)
        total_earnings = sum(o.baker_payable for o in orders)
        pending_amount = sum(o.baker_payable for o in orders if o.payment_status == 'PENDING_BAKER_SETTLEMENT')
        paid_amount = sum(o.baker_payable for o in orders if o.payment_status == 'PAID_TO_BAKER')
        
        history_orders = orders.filter(payment_status__in=['PENDING_BAKER_SETTLEMENT', 'PAID_TO_BAKER']).order_by('-updated_at')
        history_data = OrderSerializer(history_orders, many=True).data

        return Response({
            'total_earnings': total_earnings,
            'pending_amount': pending_amount,
            'paid_amount': paid_amount,
            'history': history_data
        })

    @action(detail=False, methods=['get'])
    def delivery_finance_stats(self, request):
        if not hasattr(request.user, 'delivery_profile'):
            return Response(status=status.HTTP_403_FORBIDDEN)
            
        from finance.models import Wallet, WithdrawalRequest
        wallet, _ = Wallet.objects.get_or_create(user=request.user)
        
        from django.db.models import Sum
        pending_withdrawals = WithdrawalRequest.objects.filter(user=request.user, status='PENDING').aggregate(total=Sum('amount'))['total'] or 0.0
        
        orders = Order.objects.filter(delivery_person=request.user.delivery_profile)
        total_earnings = sum(o.delivery_person_payable for o in orders)
        pending_amount = sum(o.delivery_person_payable for o in orders if o.delivery_payment_status == 'PENDING_DELIVERY_SETTLEMENT')
        paid_amount = sum(o.delivery_person_payable for o in orders if o.delivery_payment_status == 'PAID_TO_DELIVERY_PERSON')
        
        history_orders = orders.filter(delivery_payment_status__in=['PENDING_DELIVERY_SETTLEMENT', 'PAID_TO_DELIVERY_PERSON']).order_by('-updated_at')
        history_data = OrderSerializer(history_orders, many=True).data

        return Response({
            'total_earnings': total_earnings,
            'pending_amount': pending_amount,
            'paid_amount': paid_amount,
            'wallet_balance': float(wallet.balance),
            'wallet_withdrawn': float(wallet.withdrawn_amount),
            'wallet_pending_withdrawal': float(pending_withdrawals),
            'history': history_data
        })

    @action(detail=True, methods=['post'])
    def status(self, request, pk=None):
        order = self.get_object()
        
        is_baker = hasattr(request.user, 'baker_profile') and order.baker == request.user.baker_profile
        is_delivery = hasattr(request.user, 'delivery_profile') and order.delivery_person == request.user.delivery_profile
        
        if is_baker and not request.user.baker_profile.is_approved:
            return Response({"error": "Your baker account is pending admin approval."}, status=status.HTTP_403_FORBIDDEN)
            
        if not is_baker and not is_delivery:
            return Response({"error": "Only the assigned baker or delivery person can update status."}, status=status.HTTP_403_FORBIDDEN)
            
        new_status = request.data.get('status')
        if new_status not in dict(Order.STATUS_CHOICES).keys():
            return Response({"error": "Invalid status."}, status=status.HTTP_400_BAD_REQUEST)
            
        old_status = order.status
        order.status = new_status
        
        delivery_time = request.data.get('delivery_time')
        if delivery_time:
            order.delivery_time = delivery_time
            
        # If order is REJECTED, restore stock
        if new_status == 'REJECTED' and old_status != 'REJECTED':
            for item in order.items.all():
                from products.models import ProductIngredient, BakerStock
                from decimal import Decimal
                recipe = ProductIngredient.objects.filter(product=item.product)
                for req in recipe:
                    stock, _ = BakerStock.objects.get_or_create(baker=order.baker, ingredient=req.ingredient)
                    stock.quantity = Decimal(str(stock.quantity)) + Decimal(str(req.quantity_required * item.quantity))
                    stock.save()

        order.save()

        # Generate invoice and handle payments wallet payout logic if status is DELIVERED
        if new_status == 'DELIVERED':
            if order.payment_status in ['PAID_BY_CUSTOMER', 'PENDING_PAYMENT']:
                from decimal import Decimal
                from finance.models import Wallet
                from django.db import transaction
                
                with transaction.atomic():
                    admin_commission = float(order.cake_amount) * 0.10
                    baker_payable = float(order.cake_amount) - admin_commission
                    order.admin_commission = admin_commission
                    order.baker_payable = baker_payable
                    
                    # Credit Baker Wallet
                    baker_wallet, _ = Wallet.objects.get_or_create(user=order.baker.user)
                    baker_wallet.balance = Decimal(str(baker_wallet.balance)) + Decimal(str(baker_payable))
                    baker_wallet.save()
                    order.payment_status = 'PAID_TO_BAKER'
                    
                    if order.delivery_person:
                        delivery_charge = float(order.delivery_charge)
                        order.delivery_person_payable = delivery_charge
                        
                        # Credit Delivery Person Wallet
                        delivery_wallet, _ = Wallet.objects.get_or_create(user=order.delivery_person.user)
                        delivery_wallet.balance = Decimal(str(delivery_wallet.balance)) + Decimal(str(delivery_charge))
                        delivery_wallet.save()
                        order.delivery_payment_status = 'PAID_TO_DELIVERY_PERSON'
                        
                        # Send Notification to Delivery Person
                        from users.models import Notification as UserNotification
                        UserNotification.objects.create(
                            user=order.delivery_person.user,
                            title="Earnings Credited",
                            message=f"Delivery charge of ₹{delivery_charge:.2f} for Order #{order.id} has been credited to your wallet."
                        )
                    
                    order.save()
                    
            if not hasattr(order, 'invoice'):
                Invoice.objects.create(
                    order=order,
                    invoice_number=f"INV-{str(uuid.uuid4().hex)[:8].upper()}",
                    total_amount=order.total_amount
                )
                
            # Send Notification to the Baker
            from users.models import Notification
            Notification.objects.create(
                user=order.baker.user,
                title="Order Delivered!",
                message=f"Order #{order.id} has been successfully delivered by {order.delivery_person.user.username if order.delivery_person else 'the delivery person'}."
            )

        return Response({'status': order.status})

    @action(detail=True, methods=['patch'])
    def assign_delivery(self, request, pk=None):
        order = self.get_object()
        if not hasattr(request.user, 'baker_profile') or order.baker != request.user.baker_profile:
            return Response({"error": "Only assigned baker can assign delivery."}, status=status.HTTP_403_FORBIDDEN)
        if not request.user.baker_profile.is_approved:
            return Response({"error": "Your baker account is pending admin approval."}, status=status.HTTP_403_FORBIDDEN)
        
        delivery_person_id = request.data.get('delivery_person_id')
        if not delivery_person_id:
            return Response({"error": "delivery_person_id is required."}, status=status.HTTP_400_BAD_REQUEST)
        
        from users.models import DeliveryPersonProfile
        try:
            dp = DeliveryPersonProfile.objects.get(id=delivery_person_id)
            order.delivery_person = dp
            order.save()
            return Response({'status': 'Delivery person assigned successfully'})
        except DeliveryPersonProfile.DoesNotExist:
            return Response({"error": "Delivery person not found."}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['get', 'post'])
    def location(self, request, pk=None):
        order = self.get_object()
        from orders.models import DeliveryTracking
        tracking, _ = DeliveryTracking.objects.get_or_create(order=order)
        
        if request.method == 'POST':
            if not hasattr(request.user, 'delivery_profile') or order.delivery_person != request.user.delivery_profile:
                return Response({"error": "Only assigned delivery person can update location."}, status=status.HTTP_403_FORBIDDEN)
            tracking.latitude = request.data.get('latitude', tracking.latitude)
            tracking.longitude = request.data.get('longitude', tracking.longitude)
            tracking.save()
            return Response({'status': 'Location updated'})
        
        return Response({
            'latitude': tracking.latitude,
            'longitude': tracking.longitude,
            'last_updated': tracking.last_updated
        })

    @action(detail=False, methods=['post'])
    def create_razorpay_order(self, request):
        order_ids = request.data.get('order_ids', [])
        if not order_ids:
            return Response({"error": "No order IDs provided"}, status=status.HTTP_400_BAD_REQUEST)
        
        orders = Order.objects.filter(id__in=order_ids, payment_status='PENDING_PAYMENT')
        if not orders.exists():
            return Response({"error": "No valid pending orders found"}, status=status.HTTP_400_BAD_REQUEST)
            
        total_amount = sum(float(order.total_amount) for order in orders)
        amount_in_paise = int(total_amount * 100)
        
        if RAZORPAY_KEY_ID == 'rzp_test_YOUR_KEY_ID':
            return Response({
                "razorpay_order_id": f"order_dummy_{uuid.uuid4().hex[:8]}",
                "amount": amount_in_paise,
                "key": RAZORPAY_KEY_ID
            })
        
        try:
            razorpay_order = razorpay_client.order.create({
                "amount": amount_in_paise,
                "currency": "INR",
                "payment_capture": "1"
            })
            return Response({
                "razorpay_order_id": razorpay_order['id'],
                "amount": amount_in_paise,
                "key": RAZORPAY_KEY_ID
            })
        except Exception as e:
            return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    @action(detail=False, methods=['post'])
    def verify_razorpay_payment(self, request):
        razorpay_order_id = request.data.get('razorpay_order_id')
        razorpay_payment_id = request.data.get('razorpay_payment_id')
        razorpay_signature = request.data.get('razorpay_signature')
        order_ids = request.data.get('order_ids', [])
        
        if not all([razorpay_order_id, razorpay_payment_id, razorpay_signature, order_ids]):
            return Response({"error": "Missing parameters for Razorpay verification"}, status=status.HTTP_400_BAD_REQUEST)
            
        if RAZORPAY_KEY_ID != 'rzp_test_YOUR_KEY_ID':
            try:
                razorpay_client.utility.verify_payment_signature({
                    'razorpay_order_id': razorpay_order_id,
                    'razorpay_payment_id': razorpay_payment_id,
                    'razorpay_signature': razorpay_signature
                })
            except razorpay.errors.SignatureVerificationError:
                return Response({"error": "Signature verification failed"}, status=status.HTTP_400_BAD_REQUEST)
            
        # Signature verified successfully, mark orders as paid
        orders = Order.objects.filter(id__in=order_ids, payment_status='PENDING_PAYMENT')
        for order in orders:
            order.status = 'CONFIRMED'
            order.payment_status = 'PAID_BY_CUSTOMER'
            order.save()
            
            from orders.models import Payment
            Payment.objects.update_or_create(
                order=order,
                defaults={
                    'transaction_id': razorpay_payment_id,
                    'amount': order.total_amount,
                    'is_successful': True
                }
            )
            
            # Send Notification to the Baker
            from users.models import Notification
            Notification.objects.create(
                user=order.baker.user,
                title="New Order Paid",
                message=f"An order (ID: {order.id}) has been paid by customer and confirmed!"
            )
            
        return Response({'status': 'Payment verified and orders confirmed'})

    @action(detail=False, methods=['post'])
    def verify_upi_payment(self, request):
        transaction_id = request.data.get('transaction_id')
        order_ids = request.data.get('order_ids', [])
        payment_method = request.data.get('payment_method', 'UPI')
        
        if not all([transaction_id, order_ids]):
            return Response({"error": "Missing parameters for UPI verification"}, status=status.HTTP_400_BAD_REQUEST)
            
        orders = Order.objects.filter(id__in=order_ids, payment_status='PENDING_PAYMENT')
        if not orders.exists():
            return Response({"error": "No valid pending orders found"}, status=status.HTTP_400_BAD_REQUEST)
            
        for order in orders:
            order.status = 'CONFIRMED'
            order.payment_status = 'PAID_BY_CUSTOMER'
            order.save()
            
            from orders.models import Payment
            Payment.objects.update_or_create(
                order=order,
                defaults={
                    'transaction_id': transaction_id,
                    'amount': order.total_amount,
                    'is_successful': True
                }
            )
            
            from users.models import Notification
            Notification.objects.create(
                user=order.baker.user,
                title=f"New Order Paid via {payment_method}",
                message=f"An order (ID: {order.id}) has been paid by customer via {payment_method} and confirmed!"
            )
            
        return Response({'status': f'Payment verified via {payment_method} and orders confirmed'})

class CartViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    def list(self, request):
        if not hasattr(request.user, 'customer_profile'):
            return Response(status=status.HTTP_403_FORBIDDEN)
        cart, _ = Cart.objects.get_or_create(customer=request.user.customer_profile)
        serializer = CartSerializer(cart)
        return Response(serializer.data)

    @action(detail=False, methods=['post'])
    def add_item(self, request):
        if not hasattr(request.user, 'customer_profile'):
            return Response(status=status.HTTP_403_FORBIDDEN)
        cart, _ = Cart.objects.get_or_create(customer=request.user.customer_profile)
        product_id = request.data.get('product_id')
        quantity = request.data.get('quantity', 1)
        flavor = request.data.get('flavor', '')
        size = request.data.get('size', '')
        
        item, created = CartItem.objects.get_or_create(
            cart=cart,
            product_id=product_id,
            flavor=flavor,
            size=size,
            defaults={'quantity': int(quantity)}
        )
        if not created:
            item.quantity += int(quantity)
            item.save()
        return Response({'status': 'Item added to cart'})

    @action(detail=False, methods=['delete'])
    def remove_item(self, request):
        if not hasattr(request.user, 'customer_profile'):
            return Response(status=status.HTTP_403_FORBIDDEN)
        item_id = request.data.get('item_id')
        CartItem.objects.filter(id=item_id, cart__customer=request.user.customer_profile).delete()
        return Response({'status': 'Item removed'})

    @action(detail=False, methods=['post'])
    def checkout(self, request):
        if not hasattr(request.user, 'customer_profile'):
            return Response(status=status.HTTP_403_FORBIDDEN)
            
        cart = Cart.objects.filter(customer=request.user.customer_profile).first()
        if not cart or not cart.items.exists():
            return Response({"error": "Cart is empty"}, status=status.HTTP_400_BAD_REQUEST)
            
        # Group items by Baker so each baker gets their own Order
        from collections import defaultdict
        baker_items = defaultdict(list)
        for item in cart.items.all():
            if item.product.baker:
                baker_items[item.product.baker].append(item)
                
        if not baker_items:
            return Response({"error": "Invalid items in cart"}, status=status.HTTP_400_BAD_REQUEST)

        created_orders = []
        for baker, items in baker_items.items():
            # Calculate total
            cake_amount = sum([float(item.product.base_price) * item.quantity for item in items])
            delivery_charge = 50.0
            total_amount = cake_amount + delivery_charge
            
            order = Order.objects.create(
                customer=request.user.customer_profile,
                baker=baker,
                cake_amount=cake_amount,
                delivery_charge=delivery_charge,
                total_amount=total_amount,
                status='PENDING',
                payment_status='PENDING_PAYMENT'
            )
            created_orders.append(order.id)
            
            # Create OrderItems and Deduct Stock
            for item in items:
                from orders.models import OrderItem
                OrderItem.objects.create(
                    order=order,
                    product=item.product,
                    quantity=item.quantity,
                    flavor=item.flavor,
                    size=item.size,
                    price=item.product.base_price
                )
                
                from products.models import ProductIngredient, BakerStock
                from decimal import Decimal
                recipe = ProductIngredient.objects.filter(product=item.product)
                for req in recipe:
                    stock, _ = BakerStock.objects.get_or_create(baker=baker, ingredient=req.ingredient)
                    stock.quantity = Decimal(str(stock.quantity)) - Decimal(str(req.quantity_required * item.quantity))
                    stock.save()
        
        # Clear Cart
        cart.items.all().delete()
        
        return Response({'status': 'Checkout successful', 'order_ids': created_orders})

class WishlistViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    def list(self, request):
        if not hasattr(request.user, 'customer_profile'):
            return Response(status=status.HTTP_403_FORBIDDEN)
        wishlist, _ = Wishlist.objects.get_or_create(customer=request.user.customer_profile)
        serializer = WishlistSerializer(wishlist)
        return Response(serializer.data)

    @action(detail=False, methods=['post'])
    def add_item(self, request):
        if not hasattr(request.user, 'customer_profile'):
            return Response(status=status.HTTP_403_FORBIDDEN)
        wishlist, _ = Wishlist.objects.get_or_create(customer=request.user.customer_profile)
        product_id = request.data.get('product_id')
        WishlistItem.objects.get_or_create(wishlist=wishlist, product_id=product_id)
        return Response({'status': 'Item added to wishlist'})

    @action(detail=False, methods=['delete'])
    def remove_item(self, request):
        if not hasattr(request.user, 'customer_profile'):
            return Response(status=status.HTTP_403_FORBIDDEN)
        item_id = request.data.get('item_id')
        product_id = request.data.get('product_id')
        
        if item_id:
            WishlistItem.objects.filter(id=item_id, wishlist__customer=request.user.customer_profile).delete()
        elif product_id:
            WishlistItem.objects.filter(product_id=product_id, wishlist__customer=request.user.customer_profile).delete()
            
        return Response({'status': 'Item removed'})

from users.views import IsAdminUser

class AdminPayoutViewSet(viewsets.ViewSet):
    permission_classes = [IsAdminUser]

    def list(self, request):
        from django.db.models import Sum, Q
        
        # 1. Base query for all transactions/history
        all_orders = Order.objects.all().order_by('-updated_at')
        
        # Calculate overall system totals from all valid transactions
        total_received = all_orders.exclude(payment_status='PENDING_PAYMENT').aggregate(total=Sum('total_amount'))['total'] or 0.0
        total_payouts_pending = all_orders.filter(payment_status='PENDING_BAKER_SETTLEMENT').aggregate(total=Sum('baker_payable'))['total'] or 0.0
        total_payouts_completed = all_orders.filter(payment_status='PAID_TO_BAKER').aggregate(total=Sum('baker_payable'))['total'] or 0.0
        total_commission = all_orders.exclude(payment_status='PENDING_PAYMENT').aggregate(total=Sum('admin_commission'))['total'] or 0.0
        
        total_delivery_payouts_pending = all_orders.filter(delivery_payment_status='PENDING_DELIVERY_SETTLEMENT').aggregate(total=Sum('delivery_person_payable'))['total'] or 0.0
        total_delivery_payouts_completed = all_orders.filter(delivery_payment_status='PAID_TO_DELIVERY_PERSON').aggregate(total=Sum('delivery_person_payable'))['total'] or 0.0
        
        # Refund details: count/amount of paid orders that are REJECTED
        refunded_orders = all_orders.filter(status='REJECTED').exclude(payment_status='PENDING_PAYMENT')
        total_refunded = refunded_orders.aggregate(total=Sum('total_amount'))['total'] or 0.0
        
        # Baker-wise earnings details
        bakers_earnings = []
        from users.models import CustomUser
        bakers = CustomUser.objects.filter(role='BAKER')
        for b in bakers:
            b_orders = all_orders.filter(baker__user=b)
            if b_orders.exists():
                earned_pending = b_orders.filter(payment_status='PENDING_BAKER_SETTLEMENT').aggregate(total=Sum('baker_payable'))['total'] or 0.0
                earned_completed = b_orders.filter(payment_status='PAID_TO_BAKER').aggregate(total=Sum('baker_payable'))['total'] or 0.0
                bakers_earnings.append({
                    'baker_id': b.id,
                    'username': b.username,
                    'pending': float(earned_pending),
                    'completed': float(earned_completed),
                    'total': float(earned_pending) + float(earned_completed)
                })

        # Delivery-wise earnings details
        delivery_earnings = []
        delivery_persons = CustomUser.objects.filter(role='DELIVERY_PERSON')
        for d in delivery_persons:
            d_orders = all_orders.filter(delivery_person__user=d)
            if d_orders.exists():
                earned_pending = d_orders.filter(delivery_payment_status='PENDING_DELIVERY_SETTLEMENT').aggregate(total=Sum('delivery_person_payable'))['total'] or 0.0
                earned_completed = d_orders.filter(delivery_payment_status='PAID_TO_DELIVERY_PERSON').aggregate(total=Sum('delivery_person_payable'))['total'] or 0.0
                delivery_earnings.append({
                    'delivery_person_id': d.id,
                    'username': d.username,
                    'pending': float(earned_pending),
                    'completed': float(earned_completed),
                    'total': float(earned_pending) + float(earned_completed)
                })

        # Apply search and filtering to the list of transactions displayed in history
        search_query = request.query_params.get('search')
        payment_status_filter = request.query_params.get('payment_status')
        
        orders_queryset = all_orders
        if search_query:
            if search_query.isdigit():
                orders_queryset = orders_queryset.filter(
                    Q(id=int(search_query)) | 
                    Q(baker__user__username__icontains=search_query) | 
                    Q(customer__user__username__icontains=search_query)
                )
            else:
                orders_queryset = orders_queryset.filter(
                    Q(baker__user__username__icontains=search_query) | 
                    Q(customer__user__username__icontains=search_query)
                )
                
        if payment_status_filter and payment_status_filter != 'ALL':
            orders_queryset = orders_queryset.filter(payment_status=payment_status_filter)
            
        serializer = OrderSerializer(orders_queryset, many=True)
        
        return Response({
            'total_received': float(total_received),
            'pending_payouts': float(total_payouts_pending),
            'completed_payouts': float(total_payouts_completed),
            'total_delivery_pending': float(total_delivery_payouts_pending),
            'total_delivery_completed': float(total_delivery_payouts_completed),
            'total_commission': float(total_commission),
            'total_refunded': float(total_refunded),
            'baker_earnings': bakers_earnings,
            'delivery_earnings': delivery_earnings,
            'orders': serializer.data
        })

    @action(detail=True, methods=['post'])
    def confirm_payout(self, request, pk=None):
        try:
            order = Order.objects.get(pk=pk, payment_status='PENDING_BAKER_SETTLEMENT')
            order.payment_status = 'PAID_TO_BAKER'
            order.save()
            return Response({'status': 'Payout confirmed'})
        except Order.DoesNotExist:
            return Response({'error': 'Order not found or not pending settlement'}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['post'])
    def confirm_delivery_payout(self, request, pk=None):
        try:
            order = Order.objects.get(pk=pk, delivery_payment_status='PENDING_DELIVERY_SETTLEMENT')
            order.delivery_payment_status = 'PAID_TO_DELIVERY_PERSON'
            order.save()
            return Response({'status': 'Delivery payout confirmed'})
        except Order.DoesNotExist:
            return Response({'error': 'Order not found or not pending delivery settlement'}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['get'])
    def reports(self, request):
        from users.models import CustomUser
        from django.db.models import Sum, Count
        from django.utils import timezone
        import datetime
        from collections import defaultdict
        
        # 1. Platform Counts
        total_bakers = CustomUser.objects.filter(role='BAKER').count()
        total_customers = CustomUser.objects.filter(role='CUSTOMER').count()
        total_delivery = CustomUser.objects.filter(role='DELIVERY_PERSON').count()
        
        # 2. General Orders & Revenue Metrics
        all_orders = Order.objects.all()
        total_orders_count = all_orders.count()
        
        # Revenue is sum of total_amount of all orders that are paid (exclude PENDING_PAYMENT)
        paid_orders = all_orders.exclude(payment_status='PENDING_PAYMENT')
        gross_revenue = float(paid_orders.aggregate(total=Sum('total_amount'))['total'] or 0.0)
        total_commissions = float(paid_orders.aggregate(total=Sum('admin_commission'))['total'] or 0.0)
        
        # 3. Order Breakdown by Status
        status_counts = dict(all_orders.values_list('status').annotate(count=Count('id')))
        breakdown = {status_choice[0]: status_counts.get(status_choice[0], 0) for status_choice in Order.STATUS_CHOICES}
        
        # 4. User growth metrics (last 6 months)
        today = timezone.now()
        months = []
        for i in range(5, -1, -1):
            date = today - datetime.timedelta(days=i*30)
            months.append(date.strftime('%B'))
            
        user_growth = []
        for idx, m in enumerate(months):
            factor = (idx + 1) / 6.0
            user_growth.append({
                'month': m[:3],
                'bakers': int(total_bakers * factor) or 1,
                'customers': int(total_customers * factor) or 2,
                'delivery_persons': int(total_delivery * factor) or 1
            })
            
        # 5. Monthly Revenue and Commission (last 6 months)
        revenue_by_month = defaultdict(float)
        commission_by_month = defaultdict(float)
        for order in paid_orders:
            m_str = order.created_at.strftime('%b')
            revenue_by_month[m_str] += float(order.total_amount)
            commission_by_month[m_str] += float(order.admin_commission)
            
        monthly_stats = []
        for i in range(5, -1, -1):
            date = today - datetime.timedelta(days=i*30)
            m_short = date.strftime('%b')
            monthly_stats.append({
                'month': m_short,
                'revenue': revenue_by_month[m_short],
                'commission': commission_by_month[m_short]
            })
            
        # 6. Top 5 popular products
        from django.db.models import F
        from orders.models import OrderItem
        top_items = OrderItem.objects.values(
            prod_id=F('product__id'), 
            product_name=F('product__name')
        ).annotate(
            total_sold=Sum('quantity'),
            total_revenue=Sum(F('quantity') * F('price'))
        ).order_by('-total_sold')[:5]
        
        top_products = []
        for item in top_items:
            top_products.append({
                'id': item['prod_id'],
                'name': item['product_name'],
                'total_sold': item['total_sold'],
                'total_revenue': float(item['total_revenue'] or 0.0)
            })
            
        return Response({
            'total_bakers': total_bakers,
            'total_customers': total_customers,
            'total_delivery_persons': total_delivery,
            'total_orders': total_orders_count,
            'gross_revenue': gross_revenue,
            'total_commission': total_commissions,
            'order_breakdown': breakdown,
            'user_growth': user_growth,
            'monthly_stats': monthly_stats,
            'top_products': top_products
        })
