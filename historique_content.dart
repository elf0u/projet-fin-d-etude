import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'config.dart';

class HistoriqueContent extends StatefulWidget {
  const HistoriqueContent({super.key});

  @override
  State<HistoriqueContent> createState() => _HistoriqueContentState();
}

class _HistoriqueContentState extends State<HistoriqueContent>
    with SingleTickerProviderStateMixin {
  List<dynamic> data = [];
  bool isLoading = true;
  String errorMsg = "";
  late TabController _tabController;
  Timer? _refreshTimer;
  DateTime? lastUpdated;

  int _chartKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadHistory();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      loadHistory();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadHistory() async {
    try {
      final response = await http
          .get(Uri.parse(AppConfig.getChartData))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          data = jsonData['data'] ?? [];
          isLoading = false;
          errorMsg = "";
          lastUpdated = DateTime.now();
          _chartKey++;
        });
      } else {
        if (!mounted) return;
        setState(() {
          errorMsg = "Erreur serveur : ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = "Erreur de connexion";
        isLoading = false;
      });
    }
  }

  List<FlSpot> _getSpots(String key) {
    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      final val = double.tryParse(data[i][key]?.toString() ?? "");
      if (val != null) {
        spots.add(FlSpot(i.toDouble(), val));
      }
    }
    return spots;
  }

  List<String> _getLabels() {
    return data.map<String>((item) {
      final raw = item['created_at']?.toString() ?? "";
      if (raw.length >= 16) return raw.substring(11, 16);
      return raw;
    }).toList();
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    if (errorMsg.isNotEmpty && data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(errorMsg, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text("Réessayer"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
      );
    }

    if (data.isEmpty) {
      return const Center(
        child: Text(
          "Aucune donnée disponible",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final labels = _getLabels();
    final tempSpots = _getSpots('temperature');
    final humSpots = _getSpots('humidity');
    final solSpots = _getSpots('sol');

    return Column(
      children: [
        Container(
          color: Colors.green.shade700,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "📈 Historique en temps réel",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      _LiveDot(),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: loadHistory,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        tooltip: "Actualiser",
                      ),
                    ],
                  ),
                ],
              ),
              if (lastUpdated != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    "Dernière synchro : ${_formatTime(lastUpdated!)}  •  ${data.length} mesures  •  ↻ 5s",
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                tabs: const [
                  Tab(icon: Icon(Icons.thermostat), text: "Température"),
                  Tab(icon: Icon(Icons.water_drop), text: "Humidité air"),
                  Tab(icon: Icon(Icons.grass), text: "Sol"),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              KeyedSubtree(
                key: ValueKey('temp_$_chartKey'),
                child: _buildChartTab(
                  spots: tempSpots,
                  labels: labels,
                  color: Colors.orange,
                  gradientColors: [
                    Colors.orange.shade300,
                    Colors.orange.shade50
                  ],
                  unit: "°C",
                  title: "Température",
                  icon: Icons.thermostat,
                  dataKey: 'temperature',
                ),
              ),
              KeyedSubtree(
                key: ValueKey('hum_$_chartKey'),
                child: _buildChartTab(
                  spots: humSpots,
                  labels: labels,
                  color: Colors.blue,
                  gradientColors: [Colors.blue.shade300, Colors.blue.shade50],
                  unit: "%",
                  title: "Humidité air",
                  icon: Icons.water_drop,
                  dataKey: 'humidity',
                ),
              ),
              KeyedSubtree(
                key: ValueKey('sol_$_chartKey'),
                child: _buildChartTab(
                  spots: solSpots,
                  labels: labels,
                  color: Colors.brown.shade600,
                  gradientColors: [
                    Colors.brown.shade300,
                    Colors.brown.shade50
                  ],
                  unit: "",
                  title: "Humidité sol",
                  icon: Icons.grass,
                  dataKey: 'sol',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartTab({
    required List<FlSpot> spots,
    required List<String> labels,
    required Color color,
    required List<Color> gradientColors,
    required String unit,
    required String title,
    required IconData icon,
    required String dataKey,
  }) {
    if (spots.isEmpty) {
      return const Center(child: Text("Pas de données"));
    }

    final values = spots.map((s) => s.y).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final avgVal = values.reduce((a, b) => a + b) / values.length;
    final lastVal = values.last;

    final chartMin = (minVal - 2).floorToDouble();
    final chartMax = (maxVal + 2).ceilToDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 36),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Valeur actuelle",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      "${lastVal.toStringAsFixed(1)}$unit",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (lastUpdated != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Mis à jour",
                          style: TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                        Text(
                          _formatTime(lastUpdated!),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statCard("Min", "${minVal.toStringAsFixed(1)}$unit",
                  Colors.blue.shade700),
              const SizedBox(width: 8),
              _statCard("Moy", "${avgVal.toStringAsFixed(1)}$unit", color),
              const SizedBox(width: 8),
              _statCard("Max", "${maxVal.toStringAsFixed(1)}$unit",
                  Colors.red.shade700),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 260,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: LineChart(
              LineChartData(
                minY: chartMin,
                maxY: chartMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) => Text(
                        "${value.toStringAsFixed(0)}$unit",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (spots.length / 5).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= labels.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[idx],
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          "${spot.y.toStringAsFixed(1)}$unit",
                          TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        final isLast = index == spots.length - 1;
                        return FlDotCirclePainter(
                          radius: isLast ? 6 : 3,
                          color: isLast ? color : Colors.white,
                          strokeWidth: 2.5,
                          strokeColor: color,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: gradientColors
                            .map((c) => c.withOpacity(0.4))
                            .toList(),
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                "Dernières mesures",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "LIVE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              final item = data[data.length - 1 - index];
              final val = double.tryParse(item[dataKey]?.toString() ?? "");
              final valStr =
                  val != null ? "${val.toStringAsFixed(1)}$unit" : "--";
              final time = item['created_at']?.toString() ?? "";
              final isLatest = index == 0;

              return Container(
                color: isLatest ? color.withOpacity(0.05) : null,
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: isLatest
                        ? color.withOpacity(0.2)
                        : color.withOpacity(0.08),
                    child: Icon(
                      icon,
                      size: 16,
                      color: isLatest ? color : color.withOpacity(0.6),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        valStr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 15,
                        ),
                      ),
                      if (isLatest) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Dernière",
                            style:
                                TextStyle(color: Colors.white, fontSize: 9),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Text(
                    time.length >= 19 ? time.substring(11, 19) : time,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.circle, color: Colors.white, size: 8),
            SizedBox(width: 4),
            Text(
              "LIVE",
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}