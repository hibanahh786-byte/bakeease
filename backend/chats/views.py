from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from django.db.models import Q
from django.contrib.auth import get_user_model
from .models import ChatMessage
from .serializers import ChatMessageSerializer, UserSimpleSerializer

User = get_user_model()

class MessageListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user_id = request.query_params.get('user_id')
        if not user_id:
            return Response({"error": "user_id query parameter is required"}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            other_user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)

        # Retrieve messages between request.user and other_user
        messages = ChatMessage.objects.filter(
            (Q(sender=request.user) & Q(receiver=other_user)) |
            (Q(sender=other_user) & Q(receiver=request.user))
        ).order_by('created_at')

        # Mark all messages received by request.user from other_user as read
        unread_received_messages = messages.filter(receiver=request.user, is_read=False)
        unread_received_messages.update(is_read=True)

        serializer = ChatMessageSerializer(messages, many=True)
        return Response(serializer.data)

class SendMessageView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        receiver_id = request.data.get('receiver')
        message_text = request.data.get('message')

        if not receiver_id or not message_text:
            return Response({"error": "receiver and message are required"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            receiver = User.objects.get(id=receiver_id)
        except User.DoesNotExist:
            return Response({"error": "Receiver user not found"}, status=status.HTTP_404_NOT_FOUND)

        # Prevent sending messages to oneself
        if receiver == request.user:
            return Response({"error": "Cannot send message to yourself"}, status=status.HTTP_400_BAD_REQUEST)

        message = ChatMessage.objects.create(
            sender=request.user,
            receiver=receiver,
            message=message_text
        )

        serializer = ChatMessageSerializer(message)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

class ConversationListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        current_user = request.user

        # Find all messages involving the current user
        all_messages = ChatMessage.objects.filter(
            Q(sender=current_user) | Q(receiver=current_user)
        ).order_by('-created_at')

        # Extract unique interlocutor user IDs
        interlocutors_ids = set()
        for msg in all_messages:
            if msg.sender_id != current_user.id:
                interlocutors_ids.add(msg.sender_id)
            if msg.receiver_id != current_user.id:
                interlocutors_ids.add(msg.receiver_id)

        conversations = []
        for other_id in interlocutors_ids:
            try:
                other_user = User.objects.get(id=other_id)
            except User.DoesNotExist:
                continue

            # Get the last message exchanged
            last_msg = ChatMessage.objects.filter(
                (Q(sender=current_user) & Q(receiver=other_user)) |
                (Q(sender=other_user) & Q(receiver=current_user))
            ).order_by('-created_at').first()

            if not last_msg:
                continue

            # Calculate unread count received from this specific user
            unread_count = ChatMessage.objects.filter(
                sender=other_user,
                receiver=current_user,
                is_read=False
            ).count()

            conversations.append({
                "other_user": UserSimpleSerializer(other_user).data,
                "last_message": {
                    "id": last_msg.id,
                    "message": last_msg.message,
                    "created_at": last_msg.created_at,
                    "sender_id": last_msg.sender_id
                },
                "unread_count": unread_count
            })

        # Sort conversations by last message timestamp (newest first)
        conversations.sort(key=lambda x: x['last_message']['created_at'], reverse=True)

        return Response(conversations)
