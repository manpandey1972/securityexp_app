import 'package:flutter/material.dart';
import 'package:greenhive_app/shared/themes/app_theme_dark.dart';
import 'package:greenhive_app/shared/widgets/app_button_variants.dart';

class ProductDetailsPage extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductDetailsPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final title =
        product['title']?.toString() ??
        product['name']?.toString() ??
        'Product';
    final desc =
        product['description']?.toString() ??
        product['details']?.toString() ??
        '';
    final price = product['price']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: AppSpacing.spacing8),
            if (price.isNotEmpty)
              Text(
                'Price: $price',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            SizedBox(height: AppSpacing.spacing12),
            Text(desc),
            const Spacer(),
            AppButtonVariants.primary(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: Text(
                      'Purchase',
                      style: AppTypography.bodyRegular,
                    ),
                    content: Text(
                      'Purchase $title - placeholder flow',
                      style: AppTypography.bodyRegular,
                    ),
                    actions: [
                      AppButtonVariants.dialogAction(
                        onPressed: () => Navigator.of(ctx).pop(),
                        label: 'OK',
                      ),
                    ],
                  ),
                );
              },
              label: 'Buy Now',
            ),
          ],
        ),
      ),
    );
  }
}
