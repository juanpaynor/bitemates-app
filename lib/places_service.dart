
import 'package:dio/dio.dart';
import 'dart:developer' as developer;

class PlacesService {
  final String apiKey;
  final Dio _dio = Dio();

  PlacesService(this.apiKey);

  Future<Map<String, dynamic>?> findPlace() async {
    const url = 'https://maps.googleapis.com/maps/api/place/findplacefromtext/json';

    if (apiKey == 'YOUR_API_KEY' || apiKey.isEmpty) {
      developer.log(
        'API Key is missing. Please add your Google Places API key in home_screen.dart.',
        name: 'com.bitemates.places',
        level: 1000, // SEVERE
      );
      return null;
    }

    try {
      final response = await _dio.get(
        url,
        queryParameters: {
          'input': 'restaurant',
          'inputtype': 'textquery',
          'fields': 'place_id,name,rating,formatted_address,geometry,price_level,types',
          'locationbias': 'circle:5000@14.463244921810706,121.02471129025434',
          'minprice': '3',
          'maxprice': '4',
          'opennow': 'true',
          'rating': '4.7',
          'key': apiKey,
        },
      );

      if (response.statusCode == 200 && response.data['candidates'] != null && response.data['candidates'].isNotEmpty) {
        final placeId = response.data['candidates'][0]['place_id'];
        return await _getPlaceDetails(placeId);
      } else {
        developer.log(
          'Find Place API call failed: ${response.data?['status']} - ${response.data?['error_message']}',
          name: 'com.bitemates.places',
          level: 900, // WARNING
        );
        return null;
      }
    } on DioException catch (e, s) {
      developer.log(
        'Error finding place',
        name: 'com.bitemates.places',
        error: e,
        stackTrace: s,
        level: 1000, // SEVERE
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getPlaceDetails(String placeId) async {
    const url = 'https://maps.googleapis.com/maps/api/place/details/json';
    try {
      final response = await _dio.get(
        url,
        queryParameters: {
          'place_id': placeId,
          'fields': 'name,formatted_address,geometry,price_level,types',
          'key': apiKey,
        },
      );

      if (response.statusCode == 200 && response.data['result'] != null) {
        return response.data['result'];
      } else {
        developer.log(
          'Place Details API call failed: ${response.data?['status']} - ${response.data?['error_message']}',
          name: 'com.bitemates.places',
          level: 900, // WARNING
        );
        return null;
      }
    } on DioException catch (e, s) {
      developer.log(
        'Error getting place details',
        name: 'com.bitemates.places',
        error: e,
        stackTrace: s,
        level: 1000, // SEVERE
      );
      return null;
    }
  }
}
