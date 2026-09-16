import os
import sys
import django

sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'backend'))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'settings')
django.setup()

from django.contrib.auth import get_user_model
User = get_user_model()

print("--- Recent Users ---")
for u in User.objects.all().order_by('-date_joined')[:5]:
    print(f"ID: {u.id} | Username: {u.username} | Role: {u.role} | Joined: {u.date_joined} | Active: {u.is_active}")
