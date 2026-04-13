import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class VARIResult {
  final double mean;
  final double median;
  final double stdDev;
  final double min;
  final double max;
  final int pixelCount;
  final ui.Image variMap;

  const VARIResult({
    required this.mean,
    required this.median,
    required this.stdDev,
    required this.min,
    required this.max,
    required this.pixelCount,
    required this.variMap,
  });

  String get vigorLabel {
    if (mean >= 0.3) return 'Alto vigor';
    if (mean >= 0.1) return 'Vigor moderado';
    if (mean >= 0.0) return 'Baixo vigor';
    return 'Estresse';
  }

  Color get vigorColor {
    if (mean >= 0.3) return const Color(0xFF1B5E20);
    if (mean >= 0.1) return const Color(0xFF43A047);
    if (mean >= 0.0) return const Color(0xFFFDD835);
    return const Color(0xFFE53935);
  }
}

/// Calibration factors derived from the reference panel photos.
class CalibrationFactors {
  final double r;
  final double g;
  final double b;
  const CalibrationFactors({required this.r, required this.g, required this.b});
  factory CalibrationFactors.neutral() => const CalibrationFactors(r: 1.0, g: 1.0, b: 1.0);
}

/// Map a VARI value in [-1, 1] to an RGB color (red→yellow→green).
Color _variToColor(double v) {
  final t = ((v + 1.0) / 2.0).clamp(0.0, 1.0);
  if (t <= 0.5) {
    final f = t / 0.5;
    return Color.fromARGB(255, 255, (f * 255).round(), 0);
  } else {
    final f = (t - 0.5) / 0.5;
    return Color.fromARGB(255, ((1 - f) * 255).round(), 255, 0);
  }
}

/// Derive calibration factors from entry and exit panel images.
/// Uses the mean channel values relative to each other.
Future<CalibrationFactors> deriveCalibration(File entryPhoto, File exitPhoto) async {
  CalibrationFactors _meanFactors(img.Image im) {
    double sumR = 0, sumG = 0, sumB = 0;
    int n = 0;
    for (final px in im) {
      sumR += px.r;
      sumG += px.g;
      sumB += px.b;
      n++;
    }
    if (n == 0) return CalibrationFactors.neutral();
    final mR = sumR / n;
    final mG = sumG / n;
    final mB = sumB / n;
    final avg = (mR + mG + mB) / 3.0;
    if (avg == 0) return CalibrationFactors.neutral();
    return CalibrationFactors(r: avg / mR, g: avg / mG, b: avg / mB);
  }

  final entryBytes = await entryPhoto.readAsBytes();
  final exitBytes = await exitPhoto.readAsBytes();
  final entryImg = img.decodeImage(entryBytes);
  final exitImg = img.decodeImage(exitBytes);

  if (entryImg == null || exitImg == null) return CalibrationFactors.neutral();

  final ef = _meanFactors(entryImg);
  final xf = _meanFactors(exitImg);
  return CalibrationFactors(
    r: (ef.r + xf.r) / 2.0,
    g: (ef.g + xf.g) / 2.0,
    b: (ef.b + xf.b) / 2.0,
  );
}

/// Compute VARI statistics and colorized map from a field photo.
Future<VARIResult> computeVARI(
  File fieldPhoto,
  CalibrationFactors cal, {
  int step = 2,
}) async {
  final bytes = await fieldPhoto.readAsBytes();
  final source = img.decodeImage(bytes);
  if (source == null) throw Exception('Não foi possível decodificar a imagem');

  final w = source.width;
  final h = source.height;

  // ── Statistics (subsampled) ────────────────────────────────────────────────
  final List<double> values = [];
  for (int y = 0; y < h; y += step) {
    for (int x = 0; x < w; x += step) {
      final px = source.getPixel(x, y);
      final r = (px.r * cal.r / 255.0).clamp(0.0, 1.0);
      final g = (px.g * cal.g / 255.0).clamp(0.0, 1.0);
      final b = (px.b * cal.b / 255.0).clamp(0.0, 1.0);
      final denom = g + r - b;
      if (denom.abs() > 1e-6) {
        final vari = ((g - r) / denom).clamp(-1.0, 1.0);
        values.add(vari);
      }
    }
  }

  if (values.isEmpty) throw Exception('Nenhum pixel VARI válido');

  values.sort();
  final mean = values.reduce((a, b) => a + b) / values.length;
  final median = values[values.length ~/ 2];
  final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
  final stdDev = sqrt(variance);

  // ── Colorized map (full resolution) ───────────────────────────────────────
  final pixels = Uint8List(w * h * 4);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final px = source.getPixel(x, y);
      final r = (px.r * cal.r / 255.0).clamp(0.0, 1.0);
      final g = (px.g * cal.g / 255.0).clamp(0.0, 1.0);
      final b = (px.b * cal.b / 255.0).clamp(0.0, 1.0);
      final denom = g + r - b;
      final vari = denom.abs() > 1e-6 ? ((g - r) / denom).clamp(-1.0, 1.0) : 0.0;
      final c = _variToColor(vari);
      final idx = (y * w + x) * 4;
      pixels[idx] = c.red;
      pixels[idx + 1] = c.green;
      pixels[idx + 2] = c.blue;
      pixels[idx + 3] = 255;
    }
  }

  final codec = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    codec,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final frameCodec = await descriptor.instantiateCodec();
  final frame = await frameCodec.getNextFrame();

  return VARIResult(
    mean: mean,
    median: median,
    stdDev: stdDev,
    min: values.first,
    max: values.last,
    pixelCount: values.length,
    variMap: frame.image,
  );
}
