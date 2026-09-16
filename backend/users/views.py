from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.permissions import BasePermission
from rest_framework_simplejwt.views import TokenObtainPairView
from django.contrib.auth import get_user_model
from users.serializers import UserSerializer, BakerProfileSerializer, CustomerProfileSerializer, DeliveryPersonProfileSerializer, ComplaintSerializer
from users.models import BakerProfile, CustomerProfile, DeliveryPersonProfile, Complaint

class IsAdminUser(BasePermission):
    def has_permission(self, request, view):
        return bool(
            request.user and 
            request.user.is_authenticated and 
            (request.user.role == 'ADMIN' or request.user.is_superuser or getattr(request.user, 'is_staff', False))
        )

User = get_user_model()

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (permissions.AllowAny,)
    serializer_class = UserSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        # Auto-create profile based on role
        contact_number = request.data.get('contact_number', '')
        address = request.data.get('address', '')

        if user.role == 'BAKER':
            fssai_number = request.data.get('fssai_number', '')
            fssai_document = request.data.get('fssai_document')
            BakerProfile.objects.create(
                user=user, 
                contact_number=contact_number,
                fssai_number=fssai_number,
                fssai_document=fssai_document
            )
        elif user.role == 'CUSTOMER':
            CustomerProfile.objects.create(user=user, contact_number=contact_number, address=address)
        elif user.role == 'DELIVERY_PERSON':
            vehicle_details = request.data.get('vehicle_details', '')
            DeliveryPersonProfile.objects.create(user=user, contact_number=contact_number, vehicle_details=vehicle_details)

        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)

class UserDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = User.objects.all()
    permission_classes = (permissions.IsAuthenticated,)
    serializer_class = UserSerializer

    def get_object(self):
        return self.request.user

class BakerProfileView(generics.RetrieveUpdateAPIView):
    queryset = BakerProfile.objects.all()
    permission_classes = (permissions.IsAuthenticated,)
    serializer_class = BakerProfileSerializer

    def get_object(self):
        return self.request.user.baker_profile

class CustomerProfileView(generics.RetrieveUpdateAPIView):
    queryset = CustomerProfile.objects.all()
    permission_classes = (permissions.IsAuthenticated,)
    serializer_class = CustomerProfileSerializer

    def get_object(self):
        return self.request.user.customer_profile

class DeliveryPersonProfileView(generics.RetrieveUpdateAPIView):
    queryset = DeliveryPersonProfile.objects.all()
    permission_classes = (permissions.IsAuthenticated,)
    serializer_class = DeliveryPersonProfileSerializer
    
    def get_object(self):
        return self.request.user.delivery_profile

class AdminBakerListView(generics.ListAPIView):
    queryset = BakerProfile.objects.all()
    permission_classes = [IsAdminUser]
    serializer_class = BakerProfileSerializer

class AdminBakerApproveView(generics.UpdateAPIView):
    queryset = BakerProfile.objects.all()
    permission_classes = [IsAdminUser]
    serializer_class = BakerProfileSerializer

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        instance.is_approved = request.data.get('is_approved', True)
        instance.save()
        serializer = self.get_serializer(instance)
        return Response(serializer.data)

class DeliveryPersonListView(generics.ListAPIView):
    queryset = DeliveryPersonProfile.objects.all()
    permission_classes = (permissions.IsAuthenticated,)
    serializer_class = DeliveryPersonProfileSerializer

class AdminUserListView(generics.ListAPIView):
    queryset = User.objects.all().order_by('id')
    permission_classes = [IsAdminUser]
    serializer_class = UserSerializer

class AdminUserToggleActiveView(generics.UpdateAPIView):
    queryset = User.objects.all()
    permission_classes = [IsAdminUser]
    serializer_class = UserSerializer

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        instance.is_active = request.data.get('is_active', not instance.is_active)
        instance.save()
        serializer = self.get_serializer(instance)
        return Response(serializer.data)

class AdminComplaintListView(generics.ListAPIView):
    queryset = Complaint.objects.all().order_by('-created_at')
    permission_classes = [IsAdminUser]
    serializer_class = ComplaintSerializer

class AdminComplaintResolveView(generics.UpdateAPIView):
    queryset = Complaint.objects.all()
    permission_classes = [IsAdminUser]
    serializer_class = ComplaintSerializer

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        instance.status = 'RESOLVED'
        instance.save()
        serializer = self.get_serializer(instance)
        return Response(serializer.data)

class ComplaintCreateView(generics.CreateAPIView):
    queryset = Complaint.objects.all()
    permission_classes = (permissions.IsAuthenticated,)
    serializer_class = ComplaintSerializer

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

from rest_framework.decorators import action
from rest_framework import viewsets
from .models import Notification
from .serializers import NotificationSerializer

class NotificationViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return self.request.user.notifications.all()

    @action(detail=False, methods=['post'])
    def mark_all_read(self, request):
        self.get_queryset().update(is_read=True)
        return Response({'status': 'all marked as read'})
