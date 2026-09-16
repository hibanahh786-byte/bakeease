from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from products.models import Product, Category, Rating, Ingredient, BakerStock, ProductIngredient
from products.serializers import ProductSerializer, CategorySerializer, IngredientSerializer, BakerStockSerializer, ProductIngredientSerializer

class CategoryViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [permissions.AllowAny]

class ProductViewSet(viewsets.ModelViewSet):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer

    def get_queryset(self):
        user = self.request.user
        queryset = Product.objects.filter(is_approved=True)

        category = self.request.query_params.get('category')
        search = self.request.query_params.get('search')
        ordering = self.request.query_params.get('ordering')
        location = self.request.query_params.get('location')

        if location:
            queryset = queryset.filter(baker__city__icontains=location)

        if category and category.lower() != 'all':
            queryset = queryset.filter(category__name__icontains=category)
            
        if search:
            queryset = queryset.filter(name__icontains=search)

        if ordering in ['base_price', '-base_price', 'name', '-name']:
            queryset = queryset.order_by(ordering)

        if user.is_authenticated:
            if user.is_staff or user.is_superuser:
                queryset = Product.objects.all()
                if category and category.lower() != 'all':
                    queryset = queryset.filter(category__name__icontains=category)
                if search:
                    queryset = queryset.filter(name__icontains=search)
                return queryset
            elif hasattr(user, 'baker_profile'):
                pass
        
        return queryset

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            permission_classes = [permissions.AllowAny]
        else:
            permission_classes = [permissions.IsAuthenticated]
        return [permission() for permission in permission_classes]

    def perform_create(self, serializer):
        # Ensure only baker can create products
        if hasattr(self.request.user, 'baker_profile'):
            if not self.request.user.baker_profile.is_approved:
                raise permissions.PermissionDenied("Your baker account is pending admin approval.")
            serializer.save(baker=self.request.user.baker_profile, is_approved=True, is_active=True)
        else:
            raise permissions.PermissionDenied("Only Bakers can create products.")

    def perform_update(self, serializer):
        if hasattr(self.request.user, 'baker_profile'):
            if not self.request.user.baker_profile.is_approved:
                raise permissions.PermissionDenied("Your baker account is pending admin approval.")
            serializer.save(is_approved=True, is_active=True)
        else:
            raise permissions.PermissionDenied("Only Bakers can update products.")

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def my(self, request):
        if hasattr(request.user, 'baker_profile'):
            if not request.user.baker_profile.is_approved:
                return Response({"error": "Your baker account is pending admin approval."}, status=status.HTTP_403_FORBIDDEN)
            products = Product.objects.filter(baker=request.user.baker_profile)
            serializer = self.get_serializer(products, many=True)
            return Response(serializer.data)
        return Response({"error": "Only Bakers can view their own products here."}, status=status.HTTP_403_FORBIDDEN)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def rate(self, request, pk=None):
        product = self.get_object()
        user = request.user
        if not hasattr(user, 'customer_profile'):
            return Response({"error": "Only customers can rate products."}, status=status.HTTP_403_FORBIDDEN)
            
        score = request.data.get('score')
        review = request.data.get('review', '')
        
        try:
            score = int(score)
        except (TypeError, ValueError):
            return Response({"error": "A valid score between 1 and 5 is required."}, status=status.HTTP_400_BAD_REQUEST)
            
        if score < 1 or score > 5:
            return Response({"error": "A valid score between 1 and 5 is required."}, status=status.HTTP_400_BAD_REQUEST)
            
        rating, created = Rating.objects.update_or_create(
            product=product,
            customer=user.customer_profile,
            defaults={'score': score, 'review': review}
        )
        
        return Response({"message": "Rating submitted successfully.", "score": rating.score}, status=status.HTTP_200_OK)

class IngredientViewSet(viewsets.ModelViewSet):
    queryset = Ingredient.objects.all()
    serializer_class = IngredientSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

class BakerStockViewSet(viewsets.ModelViewSet):
    serializer_class = BakerStockSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if hasattr(user, 'baker_profile'):
            if not user.baker_profile.is_approved:
                return BakerStock.objects.none()
            return BakerStock.objects.filter(baker=user.baker_profile)
        return BakerStock.objects.none()

    def perform_create(self, serializer):
        user = self.request.user
        if hasattr(user, 'baker_profile'):
            if not user.baker_profile.is_approved:
                raise permissions.PermissionDenied("Your baker account is pending admin approval.")
            try:
                serializer.save(baker=user.baker_profile)
            except Exception as e:
                import django.db.utils
                if isinstance(e, django.db.utils.IntegrityError):
                    from rest_framework.exceptions import ValidationError
                    raise ValidationError("You already have a stock entry for this ingredient. Please edit the existing one.")
                raise e
        else:
            raise permissions.PermissionDenied("Only Bakers can manage stock.")

class ProductIngredientViewSet(viewsets.ModelViewSet):
    serializer_class = ProductIngredientSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        product_id = self.request.query_params.get('product')
        if product_id:
            return ProductIngredient.objects.filter(product_id=product_id)
        # Fallback to all accessible ones for the baker
        user = self.request.user
        if hasattr(user, 'baker_profile'):
            if not user.baker_profile.is_approved:
                return ProductIngredient.objects.none()
            return ProductIngredient.objects.filter(product__baker=user.baker_profile)
        return ProductIngredient.objects.none()

    def perform_create(self, serializer):
        if not self.request.user.baker_profile.is_approved:
            raise permissions.PermissionDenied("Your baker account is pending admin approval.")
        product = serializer.validated_data.get('product')
        if product.baker != self.request.user.baker_profile:
            raise permissions.PermissionDenied("You can only add ingredients to your own products.")
        
        try:
            instance = serializer.save()
            from decimal import Decimal
            from products.models import BakerStock
            stock, _ = BakerStock.objects.get_or_create(baker=self.request.user.baker_profile, ingredient=instance.ingredient)
            stock.quantity = Decimal(str(stock.quantity)) - Decimal(str(instance.quantity_required))
            stock.save()
        except Exception as e:
            import django.db.utils
            if isinstance(e, django.db.utils.IntegrityError):
                from rest_framework.exceptions import ValidationError
                raise ValidationError("You already have this ingredient in the recipe. Please edit the existing one.")
            raise e

    def perform_update(self, serializer):
        if not self.request.user.baker_profile.is_approved:
            raise permissions.PermissionDenied("Your baker account is pending admin approval.")
        product = self.get_object().product
        if product.baker != self.request.user.baker_profile:
            raise permissions.PermissionDenied("You can only update ingredients of your own products.")
            
        old_instance = self.get_object()
        old_quantity = old_instance.quantity_required
        
        instance = serializer.save()
        
        from decimal import Decimal
        from products.models import BakerStock
        stock, _ = BakerStock.objects.get_or_create(baker=self.request.user.baker_profile, ingredient=instance.ingredient)
        stock.quantity = Decimal(str(stock.quantity)) + Decimal(str(old_quantity)) - Decimal(str(instance.quantity_required))
        stock.save()

    def perform_destroy(self, instance):
        if not self.request.user.baker_profile.is_approved:
            raise permissions.PermissionDenied("Your baker account is pending admin approval.")
        if instance.product.baker != self.request.user.baker_profile:
            raise permissions.PermissionDenied("You can only remove ingredients from your own products.")
            
        from decimal import Decimal
        from products.models import BakerStock
        stock, _ = BakerStock.objects.get_or_create(baker=self.request.user.baker_profile, ingredient=instance.ingredient)
        stock.quantity = Decimal(str(stock.quantity)) + Decimal(str(instance.quantity_required))
        stock.save()
        
        instance.delete()
