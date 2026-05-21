import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SavedLookDetailPage extends StatelessWidget {
  final Map<String, dynamic> savedLook;

  const SavedLookDetailPage({
    super.key,
    required this.savedLook,
  });

  List<Map<String, dynamic>> get _steps {
    final raw = savedLook['tutorial_steps'];

    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    final snapshot = savedLook['scan_snapshot'];

    if (snapshot is Map && snapshot['tutorial_steps'] is List) {
      return (snapshot['tutorial_steps'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return [
      {
        'step': 1,
        'title': 'Skin Prep',
        'description': 'Start with clean skin and prepare your face before makeup.',
      },
      {
        'step': 2,
        'title': 'Base',
        'description': 'Apply base makeup evenly and blend well.',
      },
      {
        'step': 3,
        'title': 'Brows',
        'description': 'Define your brows softly.',
      },
      {
        'step': 4,
        'title': 'Eyeshadow',
        'description': 'Apply and blend eyeshadow.',
      },
      {
        'step': 5,
        'title': 'Eyeliner',
        'description': 'Apply eyeliner close to the lash line.',
      },
      {
        'step': 6,
        'title': 'Blush',
        'description': 'Add blush to bring color to the face.',
      },
      {
        'step': 7,
        'title': 'Lips / Final Look',
        'description': 'Finish with lip color and review the final look.',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lookName = savedLook['look_name']?.toString() ?? 'Saved Look';
    final imageUrl = savedLook['image_url']?.toString();
    final imagePath = savedLook['image_path']?.toString();
    final skinTone = savedLook['skin_tone']?.toString() ?? 'N/A';
    final faceShape = savedLook['face_shape']?.toString() ?? 'N/A';

    final createdAt = DateTime.tryParse(
      savedLook['created_at']?.toString() ?? '',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF4D97),
        foregroundColor: Colors.white,
        title: Text(lookName),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 320,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEF6),
              borderRadius: BorderRadius.circular(24),
              image: _buildImageProvider(imageUrl, imagePath) != null
                  ? DecorationImage(
                      image: _buildImageProvider(imageUrl, imagePath)!,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _buildImageProvider(imageUrl, imagePath) == null
                ? const Center(
                    child: Icon(
                      Icons.face_retouching_natural,
                      color: Color(0xFFFF4D97),
                      size: 90,
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 20),

          Text(
            lookName,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1D2E),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            createdAt == null
                ? 'Saved look'
                : 'Saved ${DateFormat('MMM d, yyyy').format(createdAt)}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _infoCard(
                  title: 'Skin Tone',
                  value: skinTone,
                  icon: Icons.palette_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  title: 'Face Shape',
                  value: faceShape,
                  icon: Icons.face_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          const Text(
            'Step-by-Step Tutorial',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1D2E),
            ),
          ),

          const SizedBox(height: 12),

          ..._steps.map(_stepCard),
        ],
      ),
    );
  }

  ImageProvider? _buildImageProvider(String? imageUrl, String? imagePath) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return NetworkImage(imageUrl);
    }

    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    return null;
  }

  Widget _infoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF4D97)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepCard(Map<String, dynamic> step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFFF4D97),
            foregroundColor: Colors.white,
            child: Text('${step['step'] ?? ''}'),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step['title']?.toString() ?? 'Step',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step['description']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}