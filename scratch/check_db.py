import sqlite3

conn = sqlite3.connect('db.sqlite3')
cursor = conn.cursor()

# Get all tables
cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
tables = [t[0] for t in cursor.fetchall()]
print(f"Tables in DB: {tables}\n")

# Check users and roles
print("=== Users ===")
cursor.execute("SELECT id, username, role FROM users_customuser;")
users = cursor.fetchall()
for u in users:
    print(f"User ID: {u[0]} | Username: {u[1]} | Role: {u[2]}")

# Check delivery profiles
print("\n=== Delivery Person Profiles ===")
try:
    cursor.execute("SELECT id, user_id, vehicle_number, is_available FROM users_deliverypersonprofile;")
    profiles = cursor.fetchall()
    for p in profiles:
        print(f"Profile ID: {p[0]} | User ID: {p[1]} | Vehicle: {p[2]} | Available: {p[3]}")
except Exception as e:
    print(f"Error reading delivery profiles: {e}")

# Check orders and delivery assignments
print("\n=== Orders and Payout Details ===")
try:
    cursor.execute("SELECT id, status, delivery_person_id, delivery_charge, delivery_payment_status, total_amount FROM orders_order;")
    orders = cursor.fetchall()
    print(f"Total orders in DB: {len(orders)}")
    for o in orders[:10]:
        print(f"Order #{o[0]} | Status: {o[1]} | Delivery Person ID: {o[2]} | Delivery Charge: {o[3]} | Payment Status: {o[4]} | Total: {o[5]}")
except Exception as e:
    print(f"Error reading orders: {e}")

conn.close()
