from rest_framework import serializers
from django.db.models import Avg
from products.models import Product, Category, Rating, Ingredient, BakerStock, ProductIngredient
from users.serializers import BakerProfileSerializer

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = '__all__'

class RatingSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.user.username', read_only=True)
    class Meta:
        model = Rating
        fields = ['id', 'score', 'review', 'customer_name', 'created_at']

class IngredientSerializer(serializers.ModelSerializer):
    class Meta:
        model = Ingredient
        fields = '__all__'

class BakerStockSerializer(serializers.ModelSerializer):
    ingredient_name = serializers.CharField(source='ingredient.name', read_only=True)
    ingredient_unit = serializers.CharField(source='ingredient.unit', read_only=True)

    class Meta:
        model = BakerStock
        fields = ['id', 'ingredient', 'ingredient_name', 'ingredient_unit', 'quantity', 'low_stock_threshold']

class ProductIngredientSerializer(serializers.ModelSerializer):
    ingredient_name = serializers.CharField(source='ingredient.name', read_only=True)
    ingredient_unit = serializers.CharField(source='ingredient.unit', read_only=True)

    class Meta:
        model = ProductIngredient
        fields = ['id', 'product', 'ingredient', 'ingredient_name', 'ingredient_unit', 'quantity_required']

class ProductSerializer(serializers.ModelSerializer):
    baker = BakerProfileSerializer(read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    average_rating = serializers.SerializerMethodField()
    rating_count = serializers.SerializerMethodField()
    is_wishlisted = serializers.SerializerMethodField()
    ratings = RatingSerializer(many=True, read_only=True)
    ingredients = ProductIngredientSerializer(many=True, read_only=True)
    
    class Meta:
        model = Product
        fields = '__all__'

    def get_average_rating(self, obj):
        avg = obj.ratings.aggregate(Avg('score'))['score__avg']
        return round(avg, 1) if avg else 0.0

    def get_rating_count(self, obj):
        return obj.ratings.count()
        
    def get_is_wishlisted(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated and hasattr(request.user, 'customer_profile'):
            from orders.models import Wishlist
            wishlist, _ = Wishlist.objects.get_or_create(customer=request.user.customer_profile)
            return wishlist.items.filter(product=obj).exists()
        return False
