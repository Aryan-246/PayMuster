import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/tenant_api_client.dart';

final reviewsApiProvider = Provider<ReviewsApi>((ref) {
  return ReviewsApi(ref.read(tenantApiClientProvider));
});

/// One of the signed-in user's own reviews (GET /api/v1/reviews/mine).
class MyReview {
  const MyReview({
    required this.id,
    required this.rating,
    required this.text,
    required this.status,
    required this.createdAt,
    this.publicId,
    this.adminResponse,
    this.moderatedAt,
  });

  final String id;
  final String? publicId;
  final int rating;
  final String text;
  final String status;
  final String? adminResponse;
  final String? moderatedAt;
  final String createdAt;

  factory MyReview.fromJson(Map<String, dynamic> json) {
    return MyReview(
      id: json['id'] as String,
      publicId: json['publicId'] as String?,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      text: json['text'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      adminResponse: json['adminResponse'] as String?,
      moderatedAt: json['moderatedAt'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

/// Member/owner review submission (POST /api/v1/reviews) and own-review
/// listing. Duplicate submissions surface the server's REVIEW_DUPLICATE
/// conflict — never a fake success.
class ReviewsApi {
  const ReviewsApi(this._client);

  final TenantApiClient _client;

  Future<MyReview> submit({required int rating, required String text}) async {
    final data = await _client.post('/reviews', body: {
      'rating': rating,
      'text': text,
    });
    if (data is! Map<String, dynamic>) {
      throw const TenantApiException(
        'The review could not be submitted.',
        code: 'INVALID_RESPONSE',
      );
    }
    return MyReview.fromJson(data);
  }

  Future<List<MyReview>> listMine() async {
    final data = await _client.get('/reviews/mine');
    if (data is! List) {
      throw const TenantApiException(
        'Your reviews could not be read.',
        code: 'INVALID_RESPONSE',
      );
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(MyReview.fromJson)
        .toList();
  }
}
