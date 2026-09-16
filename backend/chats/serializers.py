from rest_framework import serializers
from .models import ChatMessage
from django.contrib.auth import get_user_model

User = get_user_model()

class UserSimpleSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'role']

class ChatMessageSerializer(serializers.ModelSerializer):
    sender_detail = UserSimpleSerializer(source='sender', read_only=True)
    receiver_detail = UserSimpleSerializer(source='receiver', read_only=True)

    class Meta:
        model = ChatMessage
        fields = ['id', 'sender', 'receiver', 'message', 'is_read', 'created_at', 'sender_detail', 'receiver_detail']
        read_only_fields = ['id', 'is_read', 'created_at']
