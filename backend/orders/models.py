from django.db import models
from users.models import CustomerProfile, BakerProfile, DeliveryPersonProfile
from products.models import Product

class Order(models.Model):
    STATUS_CHOICES = (
        ('PENDING', 'Pending'),
        ('CONFIRMED', 'Confirmed'),
        ('ORDER_IN_PROGRESS', 'Order in Progress'),
        ('OUT_FOR_DELIVERY', 'Out for Delivery'),
        ('REJECTED', 'Rejected'),
        ('DELIVERED', 'Delivered'),
    )
    PAYMENT_STATUS_CHOICES = (
        ('PENDING_PAYMENT', 'Pending Payment'),
        ('PAID_BY_CUSTOMER', 'Paid by Customer'),
        ('PENDING_BAKER_SETTLEMENT', 'Pending Baker Settlement'),
        ('PAID_TO_BAKER', 'Paid to Baker'),
    )
    DELIVERY_PAYMENT_STATUS_CHOICES = (
        ('PENDING_PAYMENT', 'Pending Payment'),
        ('PENDING_DELIVERY_SETTLEMENT', 'Pending Delivery Settlement'),
        ('PAID_TO_DELIVERY_PERSON', 'Paid to Delivery Person'),
    )
    customer = models.ForeignKey(CustomerProfile, on_delete=models.CASCADE, related_name='orders')
    baker = models.ForeignKey(BakerProfile, on_delete=models.CASCADE, related_name='orders')
    delivery_person = models.ForeignKey(DeliveryPersonProfile, on_delete=models.SET_NULL, null=True, blank=True, related_name='assigned_orders')
    status = models.CharField(max_length=25, choices=STATUS_CHOICES, default='PENDING')
    payment_status = models.CharField(max_length=50, choices=PAYMENT_STATUS_CHOICES, default='PENDING_PAYMENT')
    delivery_payment_status = models.CharField(max_length=50, choices=DELIVERY_PAYMENT_STATUS_CHOICES, default='PENDING_PAYMENT')
    cake_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.0)
    delivery_charge = models.DecimalField(max_digits=10, decimal_places=2, default=50.0)
    total_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.0)
    admin_commission = models.DecimalField(max_digits=10, decimal_places=2, default=0.0)
    baker_payable = models.DecimalField(max_digits=10, decimal_places=2, default=0.0)
    delivery_person_payable = models.DecimalField(max_digits=10, decimal_places=2, default=0.0)
    delivery_time = models.DateTimeField(blank=True, null=True)
    delivery_address = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Order {self.id} - {self.status}"

class OrderItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField(default=1)
    flavor = models.CharField(max_length=100, blank=True, null=True)
    size = models.CharField(max_length=100, blank=True, null=True)
    price = models.DecimalField(max_digits=10, decimal_places=2)

    def __str__(self):
        return f"{self.quantity} x {self.product.name}"

class CustomRequest(models.Model):
    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name='custom_request')
    custom_design_image = models.ImageField(upload_to='custom_designs/', blank=True, null=True)
    special_instructions = models.TextField(blank=True, null=True)
    delivery_date = models.DateField()

    def __str__(self):
        return f"Request for Order {self.order.id}"

class Payment(models.Model):
    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name='payment')
    transaction_id = models.CharField(max_length=100, blank=True, null=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    is_successful = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Payment {self.id} for Order {self.order.id}"

class Cart(models.Model):
    customer = models.OneToOneField(CustomerProfile, on_delete=models.CASCADE, related_name='cart')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Cart for {self.customer.user.username}"

class CartItem(models.Model):
    cart = models.ForeignKey(Cart, on_delete=models.CASCADE, related_name='items')
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField(default=1)
    flavor = models.CharField(max_length=100, blank=True, null=True)
    size = models.CharField(max_length=100, blank=True, null=True)
    
    def __str__(self):
        return f"{self.quantity} x {self.product.name} in Cart"

class Wishlist(models.Model):
    customer = models.OneToOneField(CustomerProfile, on_delete=models.CASCADE, related_name='wishlist')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Wishlist for {self.customer.user.username}"

class WishlistItem(models.Model):
    wishlist = models.ForeignKey(Wishlist, on_delete=models.CASCADE, related_name='items')
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    added_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.product.name} in Wishlist"

class DeliveryTracking(models.Model):
    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name='delivery_tracking')
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    last_updated = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Tracking for Order {self.order.id}"
