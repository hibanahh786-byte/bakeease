from rest_framework import serializers
from django.contrib.auth import get_user_model
from users.models import BakerProfile, CustomerProfile, DeliveryPersonProfile, Complaint, Notification

User = get_user_model()

class UserSerializer(serializers.ModelSerializer):
    baker_profile = serializers.SerializerMethodField()
    customer_profile = serializers.SerializerMethodField()
    delivery_profile = serializers.SerializerMethodField()
    role = serializers.CharField(required=False)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'role', 'password', 'is_active', 'baker_profile', 'customer_profile', 'delivery_profile']
        extra_kwargs = {'password': {'write_only': True}}

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        if instance.is_superuser or getattr(instance, 'is_staff', False):
            ret['role'] = 'ADMIN'
        return ret

    def get_baker_profile(self, obj):
        if hasattr(obj, 'baker_profile'):
            return {
                'id': obj.baker_profile.id,
                'fssai_number': obj.baker_profile.fssai_number,
                'is_approved': obj.baker_profile.is_approved,
                'qr_code_image': obj.baker_profile.qr_code_image.url if obj.baker_profile.qr_code_image else None,
                'city': obj.baker_profile.city,
                'address': obj.baker_profile.address,
                'bank_name': obj.baker_profile.bank_name,
                'account_number': obj.baker_profile.account_number,
                'ifsc_code': obj.baker_profile.ifsc_code,
                'account_holder_name': obj.baker_profile.account_holder_name
            }
        return None

    def get_customer_profile(self, obj):
        if hasattr(obj, 'customer_profile'):
            return {
                'id': obj.customer_profile.id,
                'address': obj.customer_profile.address,
                'contact_number': obj.customer_profile.contact_number,
                'house_name': obj.customer_profile.house_name,
                'street': obj.customer_profile.street,
                'city': obj.customer_profile.city,
                'state': obj.customer_profile.state,
                'pincode': obj.customer_profile.pincode,
                'landmarks': obj.customer_profile.landmarks
            }
        return None

    def get_delivery_profile(self, obj):
        if hasattr(obj, 'delivery_profile'):
            return {
                'id': obj.delivery_profile.id,
                'contact_number': obj.delivery_profile.contact_number,
                'vehicle_details': obj.delivery_profile.vehicle_details,
                'is_available': obj.delivery_profile.is_available,
                'bank_name': obj.delivery_profile.bank_name,
                'account_number': obj.delivery_profile.account_number,
                'ifsc_code': obj.delivery_profile.ifsc_code,
                'account_holder_name': obj.delivery_profile.account_holder_name
            }
        return None

    def create(self, validated_data):
        user = User(
            email=validated_data['email'],
            username=validated_data['username'],
            role=validated_data.get('role', 'CUSTOMER')
        )
        user.set_password(validated_data['password'])
        user.save()
        return user

class BakerProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    class Meta:
        model = BakerProfile
        fields = '__all__'

class CustomerProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    class Meta:
        model = CustomerProfile
        fields = '__all__'

class DeliveryPersonProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    class Meta:
        model = DeliveryPersonProfile
        fields = '__all__'

class ComplaintSerializer(serializers.ModelSerializer):
    username = serializers.SerializerMethodField()
    user_role = serializers.SerializerMethodField()

    class Meta:
        model = Complaint
        fields = ['id', 'user', 'username', 'user_role', 'subject', 'description', 'status', 'created_at', 'updated_at']
        read_only_fields = ['id', 'status', 'created_at', 'updated_at', 'username', 'user_role']

    def get_username(self, obj):
        return obj.user.username

    def get_user_role(self, obj):
        return obj.user.role

class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'user', 'title', 'message', 'is_read', 'created_at']
        read_only_fields = ['id', 'user', 'title', 'message', 'created_at']
