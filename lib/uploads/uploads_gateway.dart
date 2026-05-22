import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/api/api_client.dart';

/// Thin client for the shared upload service (mounted today under
/// field-svc at `/api/uploads/photos`, plus the KTP-specific OCR
/// endpoint mounted under crm-svc at `/api/crm/ktp-ocr`).
///
/// Both endpoints accept the raw bytes with an `image/*` Content-Type;
/// the GPS optional headers piggy-back as `X-Gps-Lat` / `X-Gps-Lng` so
/// we don't need multipart for round-1.
class UploadsGateway {
  UploadsGateway(this._client);

  final ApiClient _client;

  /// Uploads a single photo (JPEG/PNG/HEIC). Returns the canonical
  /// `object_url` the caller persists into the related domain row
  /// (checklist response, BAST signature, KTP, document, …).
  Future<UploadResult> uploadPhoto({
    required List<int> bytes,
    required String contentType,
    double? gpsLat,
    double? gpsLng,
    double? gpsAccuracyM,
  }) async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/uploads/photos',
      data: Stream<Uint8List>.value(Uint8List.fromList(bytes)),
      options: Options(
        method: 'POST',
        contentType: contentType,
        headers: <String, dynamic>{
          if (gpsLat != null) 'X-Gps-Lat': gpsLat.toString(),
          if (gpsLng != null) 'X-Gps-Lng': gpsLng.toString(),
          if (gpsAccuracyM != null) 'X-Gps-Accuracy': gpsAccuracyM.toString(),
          'Content-Length': bytes.length.toString(),
        },
      ),
    );
    final j = res.data!;
    return UploadResult(
      id: j['id'] as String,
      objectUrl: j['object_url'] as String,
      contentType: j['content_type'] as String? ?? contentType,
      bytes: (j['bytes'] as num?)?.toInt() ?? 0,
      sha256: j['sha256'] as String?,
    );
  }

  /// Convenience wrapper that reads a [File] before uploading. Useful
  /// for the camera + image_picker paths which hand back File handles.
  Future<UploadResult> uploadFile(
    File file, {
    required String contentType,
    double? gpsLat,
    double? gpsLng,
    double? gpsAccuracyM,
  }) async {
    final bytes = await file.readAsBytes();
    return uploadPhoto(
      bytes: bytes,
      contentType: contentType,
      gpsLat: gpsLat,
      gpsLng: gpsLng,
      gpsAccuracyM: gpsAccuracyM,
    );
  }

  /// Posts a KTP image to the CRM OCR endpoint and returns the parsed
  /// projection. Round-3 the parsing is stubbed server-side; the
  /// contract is stable so Mode A (auto-fill) keeps working when the
  /// real OCR lands.
  Future<KtpOcrResult> parseKtpImage({
    required List<int> bytes,
    required String contentType,
  }) async {
    final res = await _client.request<Map<String, dynamic>>(
      '/api/crm/ktp-ocr',
      data: Stream<Uint8List>.value(Uint8List.fromList(bytes)),
      options: Options(
        method: 'POST',
        contentType: contentType,
        headers: <String, dynamic>{
          'Content-Length': bytes.length.toString(),
        },
      ),
    );
    return KtpOcrResult.fromJson(res.data!);
  }
}

class UploadResult {
  const UploadResult({
    required this.id,
    required this.objectUrl,
    required this.contentType,
    required this.bytes,
    this.sha256,
  });
  final String id;
  final String objectUrl;
  final String contentType;
  final int bytes;
  final String? sha256;
}

class KtpOcrResult {
  const KtpOcrResult({
    required this.nik,
    required this.fullName,
    this.birthPlace,
    this.birthDate,
    this.gender,
    this.address,
    this.rtRw,
    this.kelurahan,
    this.kecamatan,
    this.religion,
    this.maritalStatus,
    this.occupation,
    this.citizenship,
    this.validUntil,
    required this.confidence,
    required this.stub,
  });

  factory KtpOcrResult.fromJson(Map<String, dynamic> j) => KtpOcrResult(
        nik: j['nik'] as String? ?? '',
        fullName: j['full_name'] as String? ?? '',
        birthPlace: j['birth_place'] as String?,
        birthDate: j['birth_date'] as String?,
        gender: j['gender'] as String?,
        address: j['address'] as String?,
        rtRw: j['rt_rw'] as String?,
        kelurahan: j['kelurahan'] as String?,
        kecamatan: j['kecamatan'] as String?,
        religion: j['religion'] as String?,
        maritalStatus: j['marital_status'] as String?,
        occupation: j['occupation'] as String?,
        citizenship: j['citizenship'] as String?,
        validUntil: j['valid_until'] as String?,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        stub: j['stub'] as bool? ?? false,
      );

  final String nik;
  final String fullName;
  final String? birthPlace;
  final String? birthDate;
  final String? gender;
  final String? address;
  final String? rtRw;
  final String? kelurahan;
  final String? kecamatan;
  final String? religion;
  final String? maritalStatus;
  final String? occupation;
  final String? citizenship;
  final String? validUntil;
  final double confidence;
  final bool stub;
}
