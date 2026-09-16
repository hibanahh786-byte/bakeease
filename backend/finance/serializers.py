from rest_framework import serializers
from finance.models import Expense, Invoice, Wallet, WithdrawalRequest
from orders.serializers import OrderSerializer
from users.serializers import BakerProfileSerializer, UserSerializer

class ExpenseSerializer(serializers.ModelSerializer):
    baker = BakerProfileSerializer(read_only=True)
    class Meta:
        model = Expense
        fields = '__all__'

class InvoiceSerializer(serializers.ModelSerializer):
    order = OrderSerializer(read_only=True)
    class Meta:
        model = Invoice
        fields = '__all__'

class WalletSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    class Meta:
        model = Wallet
        fields = '__all__'

class WithdrawalRequestSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    class Meta:
        model = WithdrawalRequest
        fields = '__all__'
