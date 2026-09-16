from django.db import models
from users.models import BakerProfile
from orders.models import Order

class Expense(models.Model):
    CATEGORY_CHOICES = [
        ('ELECTRICITY', 'Electricity'),
        ('GAS', 'Gas'),
        ('FUEL', 'Fuel'),
        ('RAW_MATERIALS', 'Raw Materials'),
        ('WAGES', 'Employee Wages'),
        ('OTHER', 'Other'),
    ]
    baker = models.ForeignKey(BakerProfile, on_delete=models.CASCADE, related_name='expenses')
    title = models.CharField(max_length=200)
    category = models.CharField(max_length=50, choices=CATEGORY_CHOICES, default='OTHER')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    description = models.TextField(blank=True, null=True)
    date_incurred = models.DateField()

    def __str__(self):
        return f"{self.title} ({self.category}) - {self.amount}"

class Invoice(models.Model):
    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name='invoice')
    invoice_number = models.CharField(max_length=50, unique=True)
    generated_at = models.DateTimeField(auto_now_add=True)
    total_amount = models.DecimalField(max_digits=10, decimal_places=2)

    def __str__(self):
        return f"Invoice {self.invoice_number}"

class Wallet(models.Model):
    user = models.OneToOneField('users.CustomUser', on_delete=models.CASCADE, related_name='wallet')
    balance = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    withdrawn_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Wallet for {self.user.username} - Balance: {self.balance}"

class WithdrawalRequest(models.Model):
    STATUS_CHOICES = [
        ('PENDING', 'Pending'),
        ('APPROVED', 'Approved'),
        ('REJECTED', 'Rejected'),
    ]
    user = models.ForeignKey('users.CustomUser', on_delete=models.CASCADE, related_name='withdrawal_requests')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    requested_at = models.DateTimeField(auto_now_add=True)
    processed_at = models.DateTimeField(null=True, blank=True)
    bank_name = models.CharField(max_length=150, blank=True, null=True)
    account_number = models.CharField(max_length=50, blank=True, null=True)
    ifsc_code = models.CharField(max_length=20, blank=True, null=True)
    account_holder_name = models.CharField(max_length=150, blank=True, null=True)

    def __str__(self):
        return f"Withdrawal of {self.amount} by {self.user.username} - {self.status}"
