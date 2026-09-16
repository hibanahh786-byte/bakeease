from django.test import TestCase
from django.contrib.auth import get_user_model
from users.models import BakerProfile, CustomerProfile
from products.models import Category, Product, Ingredient, BakerStock, ProductIngredient
from orders.models import Order, OrderItem, Cart, CartItem
from rest_framework.test import APIClient
from rest_framework import status

User = get_user_model()

class StockManagementTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        
        # Create users
        self.baker_user = User.objects.create_user(username='baker', password='password', role='BAKER')
        self.baker_profile = BakerProfile.objects.create(user=self.baker_user, fssai_number='12345678901234', is_approved=True)
        
        self.customer_user = User.objects.create_user(username='customer', password='password', role='CUSTOMER')
        self.customer_profile = CustomerProfile.objects.create(user=self.customer_user, contact_number='9876543210')
        
        # Create Category and Product
        self.category = Category.objects.create(name='Cakes')
        self.product = Product.objects.create(
            baker=self.baker_profile,
            category=self.category,
            name='Chocolate Cake',
            description='Yummy cake',
            base_price=500.00,
            available_flavors='Chocolate',
            available_sizes='1kg',
            is_active=True,
            is_approved=True
        )
        
        # Create Ingredient and Stock
        self.ingredient = Ingredient.objects.create(name='Sugar', unit='kg')
        self.stock = BakerStock.objects.create(baker=self.baker_profile, ingredient=self.ingredient, quantity=10.00, low_stock_threshold=2.00)
        
        # Create Recipe
        self.recipe = ProductIngredient.objects.create(product=self.product, ingredient=self.ingredient, quantity_required=1.5)

    def test_stock_deduction_on_checkout(self):
        # Log in as customer
        self.client.force_authenticate(user=self.customer_user)
        
        # Add item to cart
        response = self.client.post('/api/orders/cart/add_item/', {
            'product_id': self.product.id,
            'quantity': 2,
            'flavor': 'Chocolate',
            'size': '1kg'
        })
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Checkout
        response = self.client.post('/api/orders/cart/checkout/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        
        # Verify stock has decremented: 10.00 - (1.5 * 2) = 7.00
        self.stock.refresh_from_db()
        self.assertEqual(float(self.stock.quantity), 7.00)

    def test_multiple_items_with_overlapping_ingredients(self):
        # Create another product with the same ingredient (Sugar)
        product2 = Product.objects.create(
            baker=self.baker_profile,
            category=self.category,
            name='Vanilla Cake',
            description='Tasty cake',
            base_price=400.00,
            available_flavors='Vanilla',
            available_sizes='1kg',
            is_active=True,
            is_approved=True
        )
        ProductIngredient.objects.create(product=product2, ingredient=self.ingredient, quantity_required=0.5)

        # Log in as customer
        self.client.force_authenticate(user=self.customer_user)
        
        # Add both to cart
        self.client.post('/api/orders/cart/add_item/', {
            'product_id': self.product.id,
            'quantity': 2,
            'flavor': 'Chocolate',
            'size': '1kg'
        })
        self.client.post('/api/orders/cart/add_item/', {
            'product_id': product2.id,
            'quantity': 3,
            'flavor': 'Vanilla',
            'size': '1kg'
        })
        
        # Checkout
        response = self.client.post('/api/orders/cart/checkout/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        # Total Sugar deducted = (1.5 * 2) + (0.5 * 3) = 3.0 + 1.5 = 4.5
        # Remaining stock = 10.0 - 4.5 = 5.5
        self.stock.refresh_from_db()
        self.assertEqual(float(self.stock.quantity), 5.50)

    def test_product_with_no_recipe(self):
        # Create a product without recipe
        product_no_recipe = Product.objects.create(
            baker=self.baker_profile,
            category=self.category,
            name='No Recipe Cake',
            description='Just plain',
            base_price=300.00,
            is_active=True,
            is_approved=True
        )
        
        self.client.force_authenticate(user=self.customer_user)
        
        # Add both to cart
        self.client.post('/api/orders/cart/add_item/', {
            'product_id': self.product.id,
            'quantity': 2,
            'flavor': 'Chocolate',
            'size': '1kg'
        })
        self.client.post('/api/orders/cart/add_item/', {
            'product_id': product_no_recipe.id,
            'quantity': 1
        })
        
        # Checkout
        response = self.client.post('/api/orders/cart/checkout/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        # Sugar deducted should only be for self.product (1.5 * 2 = 3.0)
        self.stock.refresh_from_db()
        self.assertEqual(float(self.stock.quantity), 7.00)

    def test_baker_with_no_preexisting_stock(self):
        # Create a new ingredient and recipe, but don't add to baker's stock beforehand
        new_ingredient = Ingredient.objects.create(name='Flour', unit='kg')
        ProductIngredient.objects.create(product=self.product, ingredient=new_ingredient, quantity_required=2.0)

        self.client.force_authenticate(user=self.customer_user)
        
        # Add to cart
        self.client.post('/api/orders/cart/add_item/', {
            'product_id': self.product.id,
            'quantity': 2,
            'flavor': 'Chocolate',
            'size': '1kg'
        })
        
        # Checkout
        response = self.client.post('/api/orders/cart/checkout/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        # New stock should be created automatically with quantity = -4.0 (since initial was 0.0, and 2.0 * 2 was deducted)
        flour_stock = BakerStock.objects.get(baker=self.baker_profile, ingredient=new_ingredient)
        self.assertEqual(float(flour_stock.quantity), -4.0)
