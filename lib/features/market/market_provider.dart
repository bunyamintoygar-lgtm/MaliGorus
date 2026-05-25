import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/market_product_model.dart';
import '../../data/repositories/market_repository.dart';
import '../home/home_provider.dart';

// State notifier for category map
class MarketCategoryNotifier extends Notifier<Map<MarketProductType, String>> {
  @override
  Map<MarketProductType, String> build() => {};

  void setCategory(MarketProductType type, String category) {
    state = {...state, type: category};
  }
}

final marketCategoryProvider = NotifierProvider<MarketCategoryNotifier, Map<MarketProductType, String>>(
  MarketCategoryNotifier.new,
);

// State notifier for search keywords
class MarketSearchNotifier extends Notifier<Map<MarketProductType, String>> {
  @override
  Map<MarketProductType, String> build() => {};

  void setSearch(MarketProductType type, String query) {
    state = {...state, type: query};
  }
}

final marketSearchProvider = NotifierProvider<MarketSearchNotifier, Map<MarketProductType, String>>(
  MarketSearchNotifier.new,
);

// Dynamically fetches products based on active filters and keywords
final marketProductsProvider = FutureProvider.family<List<MarketProductModel>, MarketProductType>((ref, type) async {
  final repository = ref.watch(marketRepositoryProvider);
  final categories = ref.watch(marketCategoryProvider);
  final searches = ref.watch(marketSearchProvider);
  final searchQuery = searches[type] ?? '';
  
  // When a search query is entered, we ignore specific category chips to search all items.
  final category = searchQuery.isNotEmpty ? 'Tümü' : (categories[type] ?? 'Tümü');
  
  return repository.getProducts(
    type: type,
    category: category,
    searchPattern: searchQuery,
  );
});

// Fetches all products of a specific type without category/search filtering (useful for extracting available categories)
final unfilteredMarketProductsProvider = FutureProvider.family<List<MarketProductModel>, MarketProductType>((ref, type) async {
  final repository = ref.watch(marketRepositoryProvider);
  return repository.getProducts(
    type: type,
    category: 'Tümü',
    searchPattern: '',
  );
});

// State notifier for cart management
class MarketCartNotifier extends Notifier<AsyncValue<List<MarketProductModel>>> {
  late final MarketRepository _repository;

  @override
  AsyncValue<List<MarketProductModel>> build() {
    _repository = ref.watch(marketRepositoryProvider);
    Future.microtask(() => loadCart());
    return const AsyncValue.loading();
  }

  Future<void> loadCart() async {
    try {
      state = const AsyncValue.loading();
      final cartItems = await _repository.getCart();
      state = AsyncValue.data(cartItems);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addToCart(MarketProductModel product) async {
    try {
      await _repository.addToCart(product.id);
      
      // Update local state for immediate responsiveness
      state.whenData((items) {
        if (!items.any((item) => item.id == product.id)) {
          state = AsyncValue.data([...items, product]);
        }
      });
    } catch (e) {
      print('Add to cart failed: $e');
    }
  }

  Future<void> removeFromCart(String productId) async {
    try {
      await _repository.removeFromCart(productId);
      
      // Update local state immediately
      state.whenData((items) {
        state = AsyncValue.data(items.where((item) => item.id != productId).toList());
      });
    } catch (e) {
      print('Remove from cart failed: $e');
    }
  }

  int get totalCost {
    return state.maybeWhen(
      data: (items) => items.fold<int>(0, (sum, item) => sum + item.creditCost),
      orElse: () => 0,
    );
  }

  bool isInCart(String productId) {
    return state.maybeWhen(
      data: (items) => items.any((item) => item.id == productId),
      orElse: () => false,
    );
  }

  // Purchases execution and triggers profile credit balance refresh
  Future<bool> checkout() async {
    final items = state.value;
    if (items == null || items.isEmpty) return false;

    try {
      final success = await _repository.purchaseProducts(items);
      if (success) {
        await _repository.clearCart();
        state = const AsyncValue.data([]);
        
        // Force refresh user profile state to update credit balance in UI
        ref.invalidate(homeProvider);
        ref.invalidate(marketPurchasesProvider);
        
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> clearCart() async {
    try {
      await _repository.clearCart();
      state = const AsyncValue.data([]);
    } catch (e) {
      print('Clear cart failed: $e');
    }
  }
}

final marketCartProvider = NotifierProvider<MarketCartNotifier, AsyncValue<List<MarketProductModel>>>(
  MarketCartNotifier.new,
);

// Retrieves purchased products for authorization checks
final marketPurchasesProvider = FutureProvider<List<MarketProductModel>>((ref) async {
  final repository = ref.watch(marketRepositoryProvider);
  return repository.getMyPurchases();
});

// Provider for checking single product purchase status
final isProductPurchasedProvider = FutureProvider.family<bool, String>((ref, productId) async {
  final repository = ref.watch(marketRepositoryProvider);
  return repository.isPurchased(productId);
});

// State notifier for bookmarking/saving products
class MarketSavedNotifier extends Notifier<Set<String>> {
  late final MarketRepository _repository;

  @override
  Set<String> build() {
    _repository = ref.watch(marketRepositoryProvider);
    
    final saved = <String>{};
    for (var product in MarketProductModel.generateDummyProducts()) {
      if (_repository.isSaved(product.id)) {
        saved.add(product.id);
      }
    }
    return saved;
  }

  Future<void> toggleSaved(String productId) async {
    final isSavedNow = await _repository.toggleSaved(productId);
    if (isSavedNow) {
      state = {...state, productId};
    } else {
      state = {...state}..remove(productId);
    }
  }

  bool isSaved(String productId) => state.contains(productId);
}

final marketSavedProvider = NotifierProvider<MarketSavedNotifier, Set<String>>(
  MarketSavedNotifier.new,
);
