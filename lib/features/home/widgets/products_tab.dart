import 'package:flutter/material.dart';
import 'package:greenhive_app/data/models/models.dart' as models;
import 'package:greenhive_app/shared/themes/app_theme_dark.dart';
import 'package:greenhive_app/shared/widgets/error_state_widget.dart';
import 'package:greenhive_app/shared/widgets/empty_state_widget.dart';

/// Reusable Products Tab widget.
///
/// Displays a list of products with loading, error, and refresh states.
///
/// Usage:
/// ```dart
/// ProductsTab(
///   products: _products,
///   isLoading: _loadingProducts,
///   error: _productsError,
///   onRefresh: () => _loadProducts(),
///   onProductTap: (product) => navigateToDetails(product),
/// )
/// ```
class ProductsTab extends StatefulWidget {
  /// List of products to display
  final List<models.Product> products;

  /// Whether the list is currently loading
  final bool isLoading;

  /// Error message, if any
  final String? error;

  /// Callback when user pulls to refresh
  final Function() onRefresh;

  /// Callback when product is tapped
  /// Parameters: product data
  final Function(Map<String, dynamic>)? onProductTap;

  const ProductsTab({
    super.key,
    required this.products,
    required this.isLoading,
    this.error,
    required this.onRefresh,
    this.onProductTap,
  });

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: widget.isLoading
          ? _buildLoadingState()
          : widget.error != null
          ? _buildErrorState()
          : _buildProductsList(context),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildErrorState() {
    return ListView(
      children: [
        SizedBox(
          height: 400,
          child: ErrorStateWidget.server(
            title: 'Failed to load products',
            message: widget.error ?? 'An unexpected error occurred',
            onRetry: widget.onRefresh,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsList(BuildContext context) {
    if (widget.products.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 400,
            child: EmptyStateWidget.list(
              title: 'No products available',
              description: 'Products will appear here once they are added',
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: widget.products.length,
      itemBuilder: (context, index) {
        final product = widget.products[index];
        final title = product.name;
        final desc = ''; // Could add price or other info here

        return MouseRegion(
          key: ValueKey(product.id),
          cursor: SystemMouseCursors.click,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            elevation: 0,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AppBorders.borderRadiusNormal,
            ),
            child: InkWell(
              borderRadius: AppBorders.borderRadiusNormal,
              hoverColor: AppColors.primaryLight.withValues(alpha: 0.05),
              splashColor: AppColors.primary.withValues(alpha: 0.1),
              onTap: () {
                final productData = {
                  'name': product.name,
                  'price': product.price,
                };

                if (widget.onProductTap != null) {
                  widget.onProductTap!(productData);
                }
              },
              child: ListTile(
                leading: const Icon(Icons.shopping_bag, color: AppColors.white),
                title: Text(
                  title,
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: desc.isNotEmpty
                    ? Text(
                        desc,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
