from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from users.models import BakerProfile, CustomerProfile

class Category(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True, null=True)

    def __str__(self):
        return self.name

class Product(models.Model):
    baker = models.ForeignKey(BakerProfile, on_delete=models.CASCADE, related_name='products')
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, related_name='products')
    name = models.CharField(max_length=200)
    description = models.TextField()
    base_price = models.DecimalField(max_digits=10, decimal_places=2)
    image = models.ImageField(upload_to='product_images/', blank=True, null=True)
    available_flavors = models.TextField(help_text="Comma separated flavors", blank=True, null=True)
    available_sizes = models.TextField(help_text="Comma separated sizes (e.g., 500g, 1kg)", blank=True, null=True)
    preparation_time_hours = models.IntegerField(default=24)
    discount_price = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True, help_text="Optional discounted price")
    allows_customization = models.BooleanField(default=False, help_text="Does this product support custom cake options?")
    is_active = models.BooleanField(default=True)
    is_approved = models.BooleanField(default=False)

    def __str__(self):
        return self.name

class Rating(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='ratings')
    customer = models.ForeignKey(CustomerProfile, on_delete=models.CASCADE, related_name='ratings')
    score = models.IntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    review = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('product', 'customer')

    def __str__(self):
        return f"{self.score} stars for {self.product.name} by {self.customer.user.username}"

class Ingredient(models.Model):
    name = models.CharField(max_length=100, unique=True)
    unit = models.CharField(max_length=50, help_text="e.g., kg, liters, grams, pcs")

    def __str__(self):
        return f"{self.name} ({self.unit})"

class BakerStock(models.Model):
    baker = models.ForeignKey(BakerProfile, on_delete=models.CASCADE, related_name='stock')
    ingredient = models.ForeignKey(Ingredient, on_delete=models.CASCADE)
    quantity = models.DecimalField(max_digits=10, decimal_places=2, default=0.0)
    low_stock_threshold = models.DecimalField(max_digits=10, decimal_places=2, default=0.0)

    class Meta:
        unique_together = ('baker', 'ingredient')

    def __str__(self):
        return f"{self.baker.user.username}'s stock of {self.ingredient.name}: {self.quantity}"

class ProductIngredient(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='ingredients')
    ingredient = models.ForeignKey(Ingredient, on_delete=models.CASCADE)
    quantity_required = models.DecimalField(max_digits=10, decimal_places=2, help_text="Quantity required per unit of product")

    class Meta:
        unique_together = ('product', 'ingredient')

    def __str__(self):
        return f"{self.quantity_required} {self.ingredient.unit} of {self.ingredient.name} for {self.product.name}"
