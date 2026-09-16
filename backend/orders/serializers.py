from rest_framework import serializers
from orders.models import Order, OrderItem, CustomRequest, Payment, Cart, CartItem, Wishlist, WishlistItem, DeliveryTracking
from products.serializers import ProductSerializer
from users.serializers import CustomerProfileSerializer, BakerProfileSerializer, DeliveryPersonProfileSerializer

class OrderItemSerializer(serializers.ModelSerializer):
    product = ProductSerializer(read_only=True)
    product_id = serializers.IntegerField(write_only=True)
    class Meta:
        model = OrderItem
        fields = '__all__'
        read_only_fields = ['order']

class CustomRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomRequest
        fields = '__all__'

class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = '__all__'

class DeliveryTrackingSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeliveryTracking
        fields = '__all__'

class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, required=False)
    custom_request = CustomRequestSerializer(read_only=True)
    payment = PaymentSerializer(read_only=True)
    customer = CustomerProfileSerializer(read_only=True)
    baker = BakerProfileSerializer(read_only=True)
    delivery_person = DeliveryPersonProfileSerializer(read_only=True)
    delivery_tracking = DeliveryTrackingSerializer(read_only=True)
    baker_id = serializers.IntegerField(write_only=True)
    
    # Flat write-only fields to handle Multipart/FormData more easily
    custom_design_image = serializers.ImageField(write_only=True, required=False)
    special_instructions = serializers.CharField(write_only=True, required=False)
    requested_delivery_date = serializers.DateField(write_only=True, required=False)

    class Meta:
        model = Order
        fields = ['id', 'customer', 'baker', 'delivery_person', 'status', 'payment_status', 'delivery_payment_status', 'total_amount', 'cake_amount', 'delivery_charge', 'admin_commission', 'baker_payable', 'delivery_person_payable', 'delivery_time', 'delivery_address', 'created_at', 'updated_at', 'items', 'custom_request', 'payment', 'baker_id', 'delivery_tracking', 'custom_design_image', 'special_instructions', 'requested_delivery_date']
        read_only_fields = ['customer', 'baker', 'delivery_person', 'total_amount', 'cake_amount', 'delivery_charge', 'admin_commission', 'baker_payable', 'delivery_person_payable', 'created_at', 'updated_at', 'delivery_tracking']

    def validate_delivery_time(self, value):
        if value:
            from django.utils import timezone
            from datetime import timedelta
            min_delivery_time = timezone.now() + timedelta(hours=2) - timedelta(minutes=1)
            if value < min_delivery_time:
                raise serializers.ValidationError("Delivery time must be at least 2 hours from the current time.")
        return value

    def create(self, validated_data):
        items_data = validated_data.pop('items', [])
        baker_id = validated_data.pop('baker_id')
        
        # Pop custom request fields
        custom_design_image = validated_data.pop('custom_design_image', None)
        special_instructions = validated_data.pop('special_instructions', None)
        requested_delivery_date = validated_data.pop('requested_delivery_date', None)
        
        from decimal import Decimal
        cake_amount = sum(Decimal(str(item['price'])) * int(item['quantity']) for item in items_data)
        delivery_charge = Decimal('50.00')
        total_amount = cake_amount + delivery_charge
        
        order = Order.objects.create(baker_id=baker_id, total_amount=total_amount, cake_amount=cake_amount, delivery_charge=delivery_charge, **validated_data)
        
        for item_data in items_data:
            OrderItem.objects.create(order=order, **item_data)
            
        # Create CustomRequest if any of the fields are provided
        if custom_design_image or special_instructions or requested_delivery_date:
            from datetime import date
            CustomRequest.objects.create(
                order=order,
                custom_design_image=custom_design_image,
                special_instructions=special_instructions,
                delivery_date=requested_delivery_date or date.today()
            )
            
        return order

class CartItemSerializer(serializers.ModelSerializer):
    product = ProductSerializer(read_only=True)
    product_id = serializers.IntegerField(write_only=True)

    class Meta:
        model = CartItem
        fields = '__all__'
        read_only_fields = ['cart']

class CartSerializer(serializers.ModelSerializer):
    items = CartItemSerializer(many=True, read_only=True)

    class Meta:
        model = Cart
        fields = '__all__'

class WishlistItemSerializer(serializers.ModelSerializer):
    product = ProductSerializer(read_only=True)
    product_id = serializers.IntegerField(write_only=True)

    class Meta:
        model = WishlistItem
        fields = '__all__'
        read_only_fields = ['wishlist']

class WishlistSerializer(serializers.ModelSerializer):
    items = WishlistItemSerializer(many=True, read_only=True)

    class Meta:
        model = Wishlist
        fields = '__all__'
