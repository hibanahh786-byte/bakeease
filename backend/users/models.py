from django.db import models
from django.contrib.auth.models import AbstractUser

class CustomUser(AbstractUser):
    ROLE_CHOICES = (
        ('ADMIN', 'Admin'),
        ('BAKER', 'Baker'),
        ('CUSTOMER', 'Customer'),
        ('DELIVERY_PERSON', 'Delivery Person'),
    )
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='CUSTOMER')

    def __str__(self):
        return self.username

class BakerProfile(models.Model):
    user = models.OneToOneField(CustomUser, on_delete=models.CASCADE, related_name='baker_profile')
    contact_number = models.CharField(max_length=15, blank=True, null=True)
    city = models.CharField(max_length=100, blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    fssai_number = models.CharField(max_length=50, blank=True, null=True)
    fssai_document = models.FileField(upload_to='fssai_docs/', blank=True, null=True)
    qr_code_image = models.ImageField(upload_to='baker_qr_codes/', blank=True, null=True, help_text="Baker's payment QR code image")
    is_approved = models.BooleanField(default=False)
    bank_name = models.CharField(max_length=150, blank=True, null=True)
    account_number = models.CharField(max_length=50, blank=True, null=True)
    ifsc_code = models.CharField(max_length=20, blank=True, null=True)
    account_holder_name = models.CharField(max_length=150, blank=True, null=True)

    def __str__(self):
        return f"Baker: {self.user.username}"

class CustomerProfile(models.Model):
    user = models.OneToOneField(CustomUser, on_delete=models.CASCADE, related_name='customer_profile')
    contact_number = models.CharField(max_length=15, blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    house_name = models.CharField(max_length=100, blank=True, null=True)
    street = models.CharField(max_length=200, blank=True, null=True)
    city = models.CharField(max_length=100, blank=True, null=True)
    state = models.CharField(max_length=100, blank=True, null=True)
    pincode = models.CharField(max_length=20, blank=True, null=True)
    landmarks = models.CharField(max_length=200, blank=True, null=True)

    def __str__(self):
        return f"Customer: {self.user.username}"

class DeliveryPersonProfile(models.Model):
    user = models.OneToOneField(CustomUser, on_delete=models.CASCADE, related_name='delivery_profile')
    contact_number = models.CharField(max_length=15, blank=True, null=True)
    vehicle_details = models.CharField(max_length=100, blank=True, null=True)
    is_available = models.BooleanField(default=True)
    bank_name = models.CharField(max_length=150, blank=True, null=True)
    account_number = models.CharField(max_length=50, blank=True, null=True)
    ifsc_code = models.CharField(max_length=20, blank=True, null=True)
    account_holder_name = models.CharField(max_length=150, blank=True, null=True)

    def __str__(self):
        return f"Delivery: {self.user.username}"

class Complaint(models.Model):
    STATUS_CHOICES = [
        ('PENDING', 'Pending'),
        ('RESOLVED', 'Resolved'),
    ]
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='complaints')
    subject = models.CharField(max_length=200)
    description = models.TextField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Complaint by {self.user.username}: {self.subject}"

class Notification(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE, related_name='notifications')
    title = models.CharField(max_length=255)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Notification for {self.user.username}: {self.title}"
