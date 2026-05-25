import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class PlantAnalysisScreen extends StatefulWidget {
  const PlantAnalysisScreen({super.key});

  @override
  State<PlantAnalysisScreen> createState() => _PlantAnalysisScreenState();
}

class _PlantAnalysisScreenState extends State<PlantAnalysisScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _imageFile;
  Uint8List? _imageBytes;
  bool _analyzing = false;
  AnalysisResult? _result;
  String? _error;

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _modelLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
  try {
    _interpreter = await Interpreter.fromAsset(
      'assets/ml/plant_disease_model.tflite',
    );

    final String data =
        await rootBundle.loadString('assets/ml/labels.json');
    final Map<String, dynamic> jsonLabels = json.decode(data);

    _labels = List.generate(
      jsonLabels.length,
      (i) => jsonLabels[i.toString()].toString(),
    );

    final inputDetails = _interpreter!.getInputTensor(0);
    final outputDetails = _interpreter!.getOutputTensor(0);

    debugPrint("Input shape: ${inputDetails.shape}");
    debugPrint("Input type : ${inputDetails.type}");
    debugPrint("Output shape: ${outputDetails.shape}");
    debugPrint("Output type : ${outputDetails.type}");

    setState(() {
      _modelLoaded = true;
    });
  } catch (e) {
    setState(() {
      _error = 'Erreur chargement modèle : $e';
    });
  }
}

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      setState(() {
        _imageFile = picked;
        _imageBytes = bytes;
        _result = null;
        _error = null;
      });

      await _analyzeImage(bytes);
    } catch (e) {
      setState(() => _error = 'Erreur lors de la sélection : $e');
    }
  }

  Future<void> _analyzeImage(Uint8List bytes) async {
    if (!_modelLoaded || _interpreter == null) {
      setState(() {
        _error = 'Le modèle n’est pas encore chargé.';
      });
      return;
    }

    setState(() {
      _analyzing = true;
      _error = null;
    });

    try {
      final prediction = _predict(bytes);

final String label = prediction['label'];
final double confidence = prediction['confidence'];

if (confidence < 0.75) {
  setState(() {
    _error =
        "Image non fiable ou hors plante. Prenez une photo plus claire de la feuille.";
    _analyzing = false;
  });
  return;
}

final parsed = _buildAnalysisFromLabel(label, confidence);

      setState(() {
        _result = parsed;
        _analyzing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur analyse : $e';
        _analyzing = false;
      });
    }
  }

  Map<String, dynamic> _predict(Uint8List bytes) {
  if (_interpreter == null) {
    throw Exception("Interpreter non chargé");
  }

  final inputTensor = _interpreter!.getInputTensor(0);
  final outputTensor = _interpreter!.getOutputTensor(0);

  final inputTypeText = inputTensor.type.toString().toLowerCase();
  final outputTypeText = outputTensor.type.toString().toLowerCase();

  final bool inputIsUint8 = inputTypeText.contains('uint8');
  final bool outputIsUint8 = outputTypeText.contains('uint8');

  final input = _preprocessImage(bytes, inputIsUint8);

  dynamic output;
  if (outputIsUint8) {
    output = List.generate(1, (_) => List.filled(_labels.length, 0));
  } else {
    output = List.generate(1, (_) => List.filled(_labels.length, 0.0));
  }

  _interpreter!.run(input, output);

  List<double> scores;

  if (outputIsUint8) {
    scores = (output[0] as List)
        .map((e) => (e as int).toDouble() / 255.0)
        .toList();
  } else {
    scores = (output[0] as List)
        .map((e) => (e as num).toDouble())
        .toList();
  }

  int maxIndex = 0;
  double maxScore = scores[0];

  for (int i = 1; i < scores.length; i++) {
    if (scores[i] > maxScore) {
      maxScore = scores[i];
      maxIndex = i;
    }
  }

  final indexed = scores.asMap().entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  for (int i = 0; i < 3 && i < indexed.length; i++) {
    debugPrint(
      "Top ${i + 1}: ${_labels[indexed[i].key]} = ${(indexed[i].value * 100).toStringAsFixed(2)}%",
    );
  }

  return {
    'label': _labels[maxIndex],
    'confidence': maxScore,
  };
}

dynamic _preprocessImage(Uint8List bytes, bool inputIsUint8) {
  final img.Image? original = img.decodeImage(bytes);
  if (original == null) {
    throw Exception("Image invalide");
  }

  final img.Image resized = img.copyResize(
    original,
    width: 224,
    height: 224,
  );

  if (inputIsUint8) {
    return [
      List.generate(224, (y) {
        return List.generate(224, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r.toInt(),
            pixel.g.toInt(),
            pixel.b.toInt(),
          ];
        });
      }),
    ];
  }

  return [
    List.generate(224, (y) {
      return List.generate(224, (x) {
        final pixel = resized.getPixel(x, y);
        return [
          pixel.r / 255.0,
          pixel.g / 255.0,
          pixel.b / 255.0,
        ];
      });
    }),
  ];
}
  AnalysisResult _buildAnalysisFromLabel(String label, double confidence) {
    final normalized = label.replaceAll("___", "_").replaceAll("__", "_");
    final parts = normalized.split("_");

    String plant = "Plante inconnue";
    String disease = normalized;
    String state = "Malade";
    String gravite = "Modérée";
    bool urgence = false;
    List<String> symptomes = [];
    List<String> traitement = [];
    List<String> prevention = [];

    if (parts.isNotEmpty) {
      plant = parts.first;
      disease = parts.skip(1).join(" ").trim();
      if (disease.isEmpty) {
        disease = plant;
      }
    }

    final lower = label.toLowerCase();

    if (lower.contains("healthy")) {
      state = "Saine";
      disease = "Aucune maladie détectée";
      gravite = "Faible";
      urgence = false;
      symptomes = [
        "Feuille visuellement saine",
        "Aucun signe majeur détecté par le modèle",
        "Confiance : ${(confidence * 100).toStringAsFixed(1)}%",
      ];
      traitement = [
        "Aucun traitement nécessaire",
        "Continuer l’entretien habituel",
      ];
      prevention = [
        "Arrosage régulier",
        "Surveillance périodique",
        "Bonne aération des plantes",
      ];
    } else {
      state = "Malade";

      if (lower.contains("late_blight") ||
          lower.contains("bacterial_spot") ||
          lower.contains("leaf_mold")) {
        gravite = "Élevée";
        urgence = true;
      } else if (lower.contains("early_blight") ||
          lower.contains("septoria") ||
          lower.contains("rust")) {
        gravite = "Modérée";
      } else {
        gravite = "Faible";
      }

      symptomes = [
        "Maladie détectée : $disease",
        "Plante concernée : $plant",
        "Confiance : ${(confidence * 100).toStringAsFixed(1)}%",
      ];

      traitement = [
        "Isoler la plante si possible",
        "Retirer les feuilles atteintes",
        "Appliquer un traitement adapté à la maladie détectée",
      ];

      prevention = [
        "Éviter l’excès d’humidité",
        "Améliorer la ventilation",
        "Surveiller les autres plantes proches",
      ];
    }

    return AnalysisResult(
      plante: plant,
      etat: state,
      maladie: disease,
      gravite: gravite,
      symptomes: symptomes,
      traitement: traitement,
      prevention: prevention,
      urgence: urgence,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildHeader(),
            const SizedBox(height: 20),
            _buildImageZone(),
            const SizedBox(height: 16),
            _buildButtons(),
            const SizedBox(height: 20),
            if (!_modelLoaded && _error == null) _buildModelLoading(),
            if (_analyzing) _buildLoading(),
            if (_error != null) _buildError(),
            if (_result != null && !_analyzing) _buildResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a3d17), Color(0xFF4a7c3f)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2d5a27).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Center(
              child: Text('🔬', style: TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Diagnostic IA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Détection locale avec TensorFlow Lite',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.offline_bolt, color: Colors.white54, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Analyse 100% locale sur appareil',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageZone() {
    return Container(
      height: 260,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _imageBytes != null
              ? const Color(0xFF4a7c3f)
              : const Color(0xFFe8f0e5),
          width: _imageBytes != null ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: _imageBytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFf0f7ed),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Center(
                    child: Text('🌿', style: TextStyle(fontSize: 40)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Prenez une photo de votre plante',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2d5a27),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le modèle local analysera l’image',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: (_analyzing || !_modelLoaded)
                ? null
                : () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            label: const Text(
              'Caméra',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2d5a27),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: (_analyzing || !_modelLoaded)
                ? null
                : () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library, color: Colors.white),
            label: const Text(
              'Galerie',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4a7c3f),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
        if (_imageBytes != null) ...[
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: (_analyzing || !_modelLoaded)
                ? null
                : () => _analyzeImage(_imageBytes!),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ],
    );
  }

  Widget _buildModelLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: Color(0xFF2d5a27)),
          SizedBox(height: 16),
          Text(
            'Chargement du modèle TFLite...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2d5a27),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF2d5a27),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          const Text(
            '🤖 Analyse locale en cours...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2d5a27),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Le modèle TFLite examine votre plante',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEAEA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final r = _result!;
    final isSick = r.etat != 'Saine';
    final statusColor = r.urgence
        ? Colors.red
        : isSick
            ? Colors.orange
            : const Color(0xFF2d5a27);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    r.urgence
                        ? '🚨'
                        : isSick
                            ? '⚠️'
                            : '✅',
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.plante,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        r.etat,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (r.maladie != null && r.maladie != 'null') ...[
                      const SizedBox(height: 6),
                      Text(
                        '🦠 ${r.maladie}',
                        style: TextStyle(
                          fontSize: 13,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    'Gravité',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _graviteColor(r.gravite),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      r.gravite,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (r.symptomes.isNotEmpty) ...[
          _sectionCard(
            '🔍 Symptômes détectés',
            r.symptomes,
            Colors.orange.shade700,
            Colors.orange.shade50,
          ),
          const SizedBox(height: 12),
        ],
        if (r.traitement.isNotEmpty) ...[
          _sectionCard(
            '💊 Traitement recommandé',
            r.traitement,
            const Color(0xFF2d5a27),
            const Color(0xFFf0f7ed),
          ),
          const SizedBox(height: 12),
        ],
        if (r.prevention.isNotEmpty) ...[
          _sectionCard(
            '🛡️ Prévention',
            r.prevention,
            Colors.blue.shade700,
            Colors.blue.shade50,
          ),
          const SizedBox(height: 12),
        ],
        if (r.urgence)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade300, width: 2),
            ),
            child: const Row(
              children: [
                Text('🚨', style: TextStyle(fontSize: 24)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Action urgente requise !',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.red,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Traitez votre plante rapidement pour éviter la propagation.',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _sectionCard(
    String title,
    List<String> items,
    Color color,
    Color bgColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        color: color.withOpacity(0.85),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _graviteColor(String gravite) {
    switch (gravite.toLowerCase()) {
      case 'critique':
        return Colors.red.shade700;
      case 'élevée':
      case 'elevee':
        return Colors.red.shade400;
      case 'modérée':
      case 'moderee':
        return Colors.orange;
      case 'faible':
        return Colors.yellow.shade700;
      default:
        return Colors.green;
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }
}

class AnalysisResult {
  final String plante;
  final String etat;
  final String? maladie;
  final String gravite;
  final List<String> symptomes;
  final List<String> traitement;
  final List<String> prevention;
  final bool urgence;

  AnalysisResult({
    required this.plante,
    required this.etat,
    this.maladie,
    required this.gravite,
    required this.symptomes,
    required this.traitement,
    required this.prevention,
    required this.urgence,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      plante: json['plante']?.toString() ?? 'Inconnue',
      etat: json['etat']?.toString() ?? 'Inconnue',
      maladie: json['maladie']?.toString(),
      gravite: json['gravite']?.toString() ?? 'Inconnue',
      symptomes: _toList(json['symptomes']),
      traitement: _toList(json['traitement']),
      prevention: _toList(json['prevention']),
      urgence: json['urgence'] == true,
    );
  }

  static List<String> _toList(dynamic val) {
    if (val == null) return [];
    if (val is List) return val.map((e) => e.toString()).toList();
    return [val.toString()];
  }
}