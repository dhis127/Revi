import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import '../models/book.dart';

/// 책 커버 이미지를 표시하는 공유 위젯.
/// bytes → Image.memory, path(non-web) → Image.file, 없으면 [placeholder].
class BookCoverImage extends StatelessWidget {
  final Book book;
  final Widget placeholder;
  final BoxFit fit;
  final double? width;
  final double? height;

  const BookCoverImage({
    super.key,
    required this.book,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (book.coverImageBytes != null) {
      return Image.memory(
        book.coverImageBytes!,
        fit: fit, width: width, height: height,
      );
    }
    if (book.coverImagePath != null && !kIsWeb) {
      return Image.file(
        File(book.coverImagePath!),
        fit: fit, width: width, height: height,
      );
    }
    return placeholder;
  }
}
