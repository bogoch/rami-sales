import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Product photos from Rami Levy Online's public image CDN (by barcode).
/// Unofficial: about 2/3 of products have one; the rest (and any network
/// failure) fall back to [fallback], so the layout never depends on it.
String productImageUrl(String code, {bool large = false}) =>
    'https://img.rami-levy.co.il/product/$code/${large ? 'large' : 'small'}.jpg';

class ProductImage extends StatelessWidget {
  final String code;
  final double size;
  final Widget fallback;
  final bool large;
  const ProductImage({super.key, required this.code, required this.size, required this.fallback, this.large = false});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: size,
      height: size,
      child: CachedNetworkImage(
        imageUrl: productImageUrl(code, large: large),
        memCacheWidth: (size * dpr).round(),
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
        imageBuilder: (_, provider) => Container(
          decoration: BoxDecoration(
            color: Colors.white, // product shots are on white; keep it in dark mode too
            borderRadius: BorderRadius.circular(size * 0.22),
          ),
          padding: EdgeInsets.all(size * 0.06),
          child: Image(image: provider, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
