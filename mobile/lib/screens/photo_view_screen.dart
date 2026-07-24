import 'package:flutter/material.dart';

import '../api/api_client.dart';

/// Pełnoekranowy podgląd zdjęcia (np. paragonu) z przybliżaniem.
class PhotoViewScreen extends StatelessWidget {
  final String fileId;
  const PhotoViewScreen({super.key, required this.fileId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 6,
          child: Image.network(
            Api.i.fileUrl(fileId),
            headers: Api.i.imageHeaders,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) =>
                progress == null ? child : const CircularProgressIndicator(),
            errorBuilder: (_, __, ___) => const Text(
              'Nie udało się wczytać zdjęcia 😕',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
