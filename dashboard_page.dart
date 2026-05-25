import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mqtt_client/mqtt_client.dart' as mqtt;
import 'package:mqtt_client/mqtt_server_client.dart' as mqtt_server;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';
import 'alertes_content.dart';
import 'historique_content.dart';
import 'agrilink/app_state.dart';
import 'agrilink/theme.dart';
import 'agrilink/screens/feed_screen.dart';
import 'agrilink/screens/community_screen.dart';
import 'agrilink/screens/profile_screen.dart';
import 'agrilink/screens/publish_sheet.dart';
import 'plant_analysis_screen.dart';
import 'config.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const String brokerIp = AppConfig.mqttBrokerIp;
  static const int tcpPort = AppConfig.mqttPort;

  String temperature = "--";
  String humidity = "--";
  String sol = "--";
  String ledState = "OFF";

  bool _showAgriLink = false;
  int _iotTabIndex = 0;
  int _agriTab = 0;

  late mqtt.MqttClient client;
  bool mqttConnected = false;
  bool mqttConnecting = false;
  String mqttStatusText = "MQTT deconnecte";

  String predictionResult = "--";
  String predictionConfidence = "--";
  bool predictionLoading = false;

  String plantCondition = "";
  String plantEmoji = "";
  String plantConseil = "";
  List<dynamic> plantList = [];

  final AppState _agriState = AppState();

  Timer? predictionTimer;

  @override
  void initState() {
    super.initState();
    connectMQTT();
    fetchPrediction();
    predictionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchPrediction();
    });
    _agriState.addListener(() => setState(() {}));
  }

  Future<void> fetchPrediction() async {
    if (!mounted) return;
    setState(() => predictionLoading = true);
    try {
      final response = await http
          .get(Uri.parse(AppConfig.getPrediction))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (!mounted) return;

        setState(() {
          final predictedTemp = jsonData['predicted_temp'];
          if (predictedTemp != null) {
            final val = double.tryParse(predictedTemp.toString());
            predictionResult = val != null
                ? "Temp prevue : ${val.toStringAsFixed(2)} C"
                : predictedTemp.toString();
          } else {
            predictionResult = "Aucune prediction";
          }

          predictionConfidence = jsonData['confidence']?.toString() ?? "";

          final reco = jsonData['recommandation'];
          if (reco != null) {
            plantCondition = reco['condition']?.toString() ?? "";
            plantEmoji = reco['emoji']?.toString() ?? "";
            plantConseil = reco['conseil']?.toString() ?? "";
            plantList = reco['plantes'] ?? [];
          }

          predictionLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          predictionResult = "Erreur API";
          predictionLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        predictionResult = "Indisponible";
        predictionLoading = false;
      });
    }
  }

  void _updateLedState() {
    final t = double.tryParse(temperature);
    final h = double.tryParse(humidity);
    if (t != null && h != null) {
      setState(() {
        ledState = (h > 70.0 && t < 20.0) ? "ON" : "OFF";
      });
    }
  }

  Future<void> connectMQTT() async {
    if (mqttConnecting) return;

    if (kIsWeb) {
      setState(() {
        mqttConnected = false;
        mqttConnecting = false;
        mqttStatusText = "MQTT Web non supporté dans cette version";
      });
      return;
    }

    setState(() {
      mqttConnecting = true;
      mqttStatusText = "Connexion MQTT...";
    });

    try {
      final clientId =
          "flutter_client_${DateTime.now().millisecondsSinceEpoch}";

      client = mqtt_server.MqttServerClient(brokerIp, clientId);
      (client as mqtt_server.MqttServerClient).port = tcpPort;

      client.logging(on: true);
      client.keepAlivePeriod = 60;
      client.autoReconnect = true;
      client.onConnected = onConnected;
      client.onDisconnected = onDisconnected;

      final connMess = mqtt.MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(mqtt.MqttQos.atLeastOnce);

      client.connectionMessage = connMess;

      await client.connect();

      if (client.connectionStatus?.state ==
          mqtt.MqttConnectionState.connected) {
        client.subscribe('iot/temperature', mqtt.MqttQos.atLeastOnce);
        client.subscribe('iot/humidity', mqtt.MqttQos.atLeastOnce);
        client.subscribe('iot/sol', mqtt.MqttQos.atLeastOnce);

        client.updates?.listen((messages) {
          final mqtt.MqttReceivedMessage recMess = messages[0];
          final mqtt.MqttPublishMessage msg =
              recMess.payload as mqtt.MqttPublishMessage;

          final payload = mqtt.MqttPublishPayload.bytesToStringAsString(
              msg.payload.message);

          if (!mounted) return;

          setState(() {
            if (recMess.topic == 'iot/temperature') {
              temperature = payload;
            } else if (recMess.topic == 'iot/humidity') {
              humidity = payload;
            } else if (recMess.topic == 'iot/sol') {
              sol = payload;
            }
          });

          _updateLedState();
          fetchPrediction();
        });
      } else {
        throw Exception("Echec: ${client.connectionStatus?.returnCode}");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        mqttConnected = false;
        mqttStatusText = "MQTT : Erreur de connexion";
      });
      try {
        client.disconnect();
      } catch (_) {}
    } finally {
      if (!mounted) return;
      setState(() => mqttConnecting = false);
    }
  }

  void onConnected() {
    if (!mounted) return;
    setState(() {
      mqttConnected = true;
      mqttStatusText = "MQTT : Connecte";
    });
  }

  void onDisconnected() {
    if (!mounted) return;
    setState(() {
      mqttConnected = false;
      mqttStatusText = "MQTT : Deconnecte";
    });
  }

  void logout() {
    predictionTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  void _openPublish() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PublishSheet(state: _agriState),
    ).then((_) => setState(() {}));
  }

  void _goToAgriLink() {
    setState(() {
      _showAgriLink = true;
      _agriTab = 0;
    });
  }

  void _backToIot() {
    setState(() {
      _showAgriLink = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_showAgriLink && _agriState.currentUser != null) {
      final user = _agriState.currentUser!;
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.sensors, color: Colors.orange),
          tooltip: 'Retour IoT',
          onPressed: _backToIot,
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour, ${user.name.split(' ').first} 👋',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.darkGreen,
              ),
            ),
            Text(
              '${user.region} · ${user.specialty}',
              style:
                  const TextStyle(fontSize: 11, color: AppColors.softGreen),
            ),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text('🔔', style: TextStyle(fontSize: 20)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.lightGreen, AppColors.mediumGreen],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child:
                    Text(user.avatar, style: const TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
      );
    }

    return AppBar(
      title: Row(
        children: [
          const Text('🌱', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            _showAgriLink ? 'AgriLink' : 'Station IoT Agricole',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
      backgroundColor: AppColors.mediumGreen,
      foregroundColor: Colors.white,
      actions: _showAgriLink
          ? [
              TextButton.icon(
                onPressed: _backToIot,
                icon: const Icon(Icons.sensors, color: Colors.white, size: 18),
                label:
                    const Text('IoT', style: TextStyle(color: Colors.white)),
              ),
            ]
          : null,
    );
  }

  Widget _buildBody() {
    if (_showAgriLink) {
      return _buildAgriLinkBody();
    }

    switch (_iotTabIndex) {
      case 0:
        return DashboardContent(
          temperature: temperature,
          humidity: humidity,
          sol: sol,
          ledState: ledState,
          mqttStatus: mqttStatusText,
          mqttConnected: mqttConnected,
          mqttConnecting: mqttConnecting,
          onReconnect: connectMQTT,
          predictionResult: predictionResult,
          predictionConfidence: predictionConfidence,
          predictionLoading: predictionLoading,
          onRefreshPrediction: fetchPrediction,
          plantCondition: plantCondition,
          plantEmoji: plantEmoji,
          plantConseil: plantConseil,
          plantList: plantList,
          onGoToAgriLink: _goToAgriLink,
        );
      case 1:
        return const HistoriqueContent();
      case 2:
        return AlertesContent(
          temperature: temperature,
          humidity: humidity,
          sol: sol,
        );
      case 3:
        return const PlantAnalysisScreen();
      default:
        return const SizedBox();
    }
  }

  Widget _buildAgriLinkBody() {
    if (_agriState.currentUser == null) {
      return _AgriLinkLoginEmbed(agriState: _agriState);
    }

    switch (_agriTab) {
      case 0:
        return FeedScreen(state: _agriState, onPublish: _openPublish);
      case 1:
        return const CommunityScreen();
      case 2:
        return ProfileScreen(
          state: _agriState,
          onPublish: _openPublish,
          onLogout: () => setState(() {
            _agriState.logout();
            _agriTab = 0;
          }),
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomNav() {
    if (_showAgriLink && _agriState.currentUser != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _agriNavItem(0, '🏠', 'Accueil'),
                _agriNavItem(1, '👥', 'Communauté'),
                _agriPublishBtn(),
                _agriNavItem(2, '👤', 'Profil'),
                Expanded(
                  child: GestureDetector(
                    onTap: _backToIot,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(
                              color: Colors.orange.shade300,
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.sensors,
                                size: 18, color: Colors.orange),
                          ),
                        ),
                        const Text(
                          'IoT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return BottomNavigationBar(
      currentIndex: _iotTabIndex.clamp(0, 4),
      onTap: (index) {
        if (index == 4) {
          logout();
        } else {
          setState(() => _iotTabIndex = index);
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.mediumGreen,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.dashboard), label: 'Dashboard'),
        BottomNavigationBarItem(
            icon: Icon(Icons.show_chart), label: 'Graphiques'),
        BottomNavigationBarItem(
            icon: Icon(Icons.notifications), label: 'Alertes'),
        BottomNavigationBarItem(
            icon: Icon(Icons.biotech), label: 'Diagnostic'),
        BottomNavigationBarItem(
            icon: Icon(Icons.logout), label: 'Deconnexion'),
      ],
    );
  }

  Widget _agriNavItem(int idx, String icon, String label) {
    final active = _agriTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _agriTab = idx),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.mediumGreen : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _agriPublishBtn() {
    return Expanded(
      child: GestureDetector(
        onTap: _openPublish,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.mediumGreen, AppColors.lightGreen],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.mediumGreen.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Center(
                child: Text('➕', style: TextStyle(fontSize: 22)),
              ),
            ),
            const Text(
              'Publier',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    predictionTimer?.cancel();
    try {
      client.disconnect();
    } catch (_) {}
    super.dispose();
  }
}

class _AgriLinkLoginEmbed extends StatefulWidget {
  final AppState agriState;
  const _AgriLinkLoginEmbed({required this.agriState});

  @override
  State<_AgriLinkLoginEmbed> createState() => _AgriLinkLoginEmbedState();
}

class _AgriLinkLoginEmbedState extends State<_AgriLinkLoginEmbed> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? error;
  bool obscure = true;

  void handleLogin() async {
    setState(() {
      loading = true;
      error = null;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    final ok = await widget.agriState.login(
  emailCtrl.text.trim(),
  passCtrl.text.trim(),
);
    if (!ok) {
      setState(() {
        error = 'Email ou mot de passe incorrect.';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1a3d17),
            Color(0xFF2d5a27),
            Color(0xFF4a7c3f),
            Color(0xFF6aaf55),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text('🌱', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              const Text(
                'AgriLink',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'La communauté des agriculteurs tunisiens',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.65), fontSize: 13),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connexion AgriLink',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDeco('Email', Icons.email),
                      onSubmitted: (_) => handleLogin(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtrl,
                      obscureText: obscure,
                      decoration:
                          _inputDeco('Mot de passe', Icons.lock).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () =>
                              setState(() => obscure = !obscure),
                        ),
                      ),
                      onSubmitted: (_) => handleLogin(),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEAEA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: Color(0xFFc0392b),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading ? null : handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mediumGreen,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Se connecter  →',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Demo: ahmed@agri.tn / 123456',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.lightGreen),
        filled: true,
        fillColor: const Color(0xFFF8FAF6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.borderGreen, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.borderGreen, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.mediumGreen, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      );
}

class DashboardContent extends StatelessWidget {
  final String temperature;
  final String humidity;
  final String sol;
  final String ledState;
  final String mqttStatus;
  final bool mqttConnected;
  final bool mqttConnecting;
  final VoidCallback onReconnect;
  final String predictionResult;
  final String predictionConfidence;
  final bool predictionLoading;
  final VoidCallback onRefreshPrediction;
  final String plantCondition;
  final String plantEmoji;
  final String plantConseil;
  final List<dynamic> plantList;
  final VoidCallback onGoToAgriLink;

  const DashboardContent({
    super.key,
    required this.temperature,
    required this.humidity,
    required this.sol,
    required this.ledState,
    required this.mqttStatus,
    required this.mqttConnected,
    required this.mqttConnecting,
    required this.onReconnect,
    required this.predictionResult,
    required this.predictionConfidence,
    required this.predictionLoading,
    required this.onRefreshPrediction,
    required this.plantCondition,
    required this.plantEmoji,
    required this.plantConseil,
    required this.plantList,
    required this.onGoToAgriLink,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: mqttConnected
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: mqttConnected ? Colors.green : Colors.red),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mqttConnected ? Icons.wifi : Icons.wifi_off,
                  size: 18,
                  color: mqttConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  mqttStatus,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: mqttConnected
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              _sensorCard(
                Icons.thermostat,
                "Temperature",
                temperature == "--" ? "--" : "$temperature C",
                Colors.orange,
                Colors.orange.shade50,
              ),
              const SizedBox(width: 16),
              _sensorCard(
                Icons.water_drop,
                "Humidite air",
                humidity == "--" ? "--" : "$humidity %",
                Colors.blue,
                Colors.blue.shade50,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _sensorCard(
                Icons.grass,
                "Humidite sol",
                sol == "--" ? "--" : "$sol",
                Colors.brown.shade600,
                Colors.brown.shade50,
              ),
              const SizedBox(width: 16),
              _ledCard(),
            ],
          ),
          const SizedBox(height: 28),
          _predictionCard(),
          const SizedBox(height: 20),
          if (plantList.isNotEmpty) _plantsCard(),
          const SizedBox(height: 20),
          _agriLinkBanner(),
        ],
      ),
    );
  }

  Widget _sensorCard(
    IconData icon,
    String title,
    String value,
    Color color,
    Color bgColor,
  ) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ledCard() {
    final isOn = ledState == "ON";
    final color =
        isOn ? Colors.yellow.shade700 : Colors.grey.shade500;
    final bgColor =
        isOn ? Colors.yellow.shade50 : Colors.grey.shade100;

    return Expanded(
      child: Card(
        elevation: 3,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: isOn
                ? Border.all(color: Colors.yellow.shade600, width: 2)
                : null,
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (isOn)
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.yellow.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 4,
                          )
                        ],
                      ),
                    ),
                  Icon(
                    isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                    size: 40,
                    color: color,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text("LED",
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isOn
                      ? Colors.yellow.shade600
                      : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOn ? "ON" : "OFF",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _predictionCard() {
    IconData predIcon = Icons.psychology_alt;
    final lower = predictionResult.toLowerCase();

    if (lower.contains('danger') || lower.contains('critique')) {
      predIcon = Icons.warning_amber_rounded;
    } else if (lower.contains('attention')) {
      predIcon = Icons.info_outline;
    } else if (lower.contains('prevue') || lower.contains('normal')) {
      predIcon = Icons.check_circle_outline;
    }

    return Card(
      elevation: 4,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade700, Colors.teal.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Prediction IA",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: predictionLoading ? null : onRefreshPrediction,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: predictionLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.refresh,
                            color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(predIcon, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        predictionResult,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (predictionConfidence.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "Confiance : $predictionConfidence",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.update, color: Colors.white54, size: 14),
                SizedBox(width: 4),
                Text(
                  "Mise a jour automatique toutes les 30 s",
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _plantsCard() {
    return Card(
      elevation: 4,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.eco,
                      color: Colors.green.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Plantes recommandees",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    if (plantCondition.isNotEmpty)
                      Text(
                        "$plantEmoji  $plantCondition",
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade600),
                      ),
                  ],
                ),
              ],
            ),
            if (plantConseil.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  plantConseil,
                  style: TextStyle(
                      fontSize: 13, color: Colors.green.shade800),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ...plantList.map(
              (plante) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.07),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.local_florist,
                        color: Colors.green.shade400,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        plante['nom']?.toString() ?? "",
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _chip(Icons.thermostat,
                            plante['temp']?.toString() ?? "", Colors.orange),
                        const SizedBox(height: 4),
                        _chip(Icons.water_drop,
                            plante['hum']?.toString() ?? "", Colors.blue),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _agriLinkBanner() {
    return GestureDetector(
      onTap: onGoToAgriLink,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.darkGreen,
              AppColors.mediumGreen,
              AppColors.lightGreen
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.mediumGreen.withOpacity(0.3),
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
                  child: Text('🌍', style: TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AgriLink Communauté',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '+1,200 agriculteurs partagent leurs savoirs',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '🌾 Céréales  🫒 Oliviers  🥬 Légumes',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Rejoindre',
                style: TextStyle(
                  color: AppColors.mediumGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}