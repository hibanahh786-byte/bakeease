from django.urls import path
from .views import MessageListView, SendMessageView, ConversationListView

urlpatterns = [
    path('messages/', MessageListView.as_view(), name='message-list'),
    path('send/', SendMessageView.as_view(), name='send-message'),
    path('conversations/', ConversationListView.as_view(), name='conversation-list'),
]
