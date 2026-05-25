import 'package:flutter/material.dart';
import 'dart:async';

class AlertesContent extends StatefulWidget {
  final String temperature;
  final String humidity;
  final String sol; // ← NOUVEAU

  const AlertesContent({
    super.key,
    required this.temperature,
    required this.humidity,
    required this.sol, // ← NOUVEAU
  });

  @override
  State<AlertesContent> createState() => _AlertesContentState();
}

class _AlertesContentState extends State<AlertesContent> {
  List<Map<String, dynamic>> alertHistory = [];
  Timer? _checkTimer;

  // ── Seuils température et humidité air ──
  static const double TEMP_MAX   = 35.0;
  static const double TEMP_MIN   = 5.0;
  static const double TEMP_WARN  = 30.0;
  static const double HUM_MAX    = 90.0;
  static const double HUM_MIN    = 20.0;
  static const double HUM_WARN_H = 80.0;
  static const double HUM_WARN_L = 30.0;

  // ── Seuils humidité sol (valeurs brutes 0-4095) ── NOUVEAU
  static const double SOL_SEC_CRITIQUE = 3500.0; // trop sec
  static const double SOL_SEC_WARN     = 2800.0; // sec, arrosage recommandé
  static const double SOL_HUMIDE_WARN  = 1200.0; // trop humide attention
  static const double SOL_HUMIDE_MAX   = 800.0;  // saturé, danger

  @override
  void initState() {
    super.initState();
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkAlerts();
    });
    _checkAlerts();
  }

  @override
  void didUpdateWidget(AlertesContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.temperature != widget.temperature ||
        oldWidget.humidity    != widget.humidity    ||
        oldWidget.sol         != widget.sol) {
      _checkAlerts();
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  void _checkAlerts() {
    final temp = double.tryParse(widget.temperature);
    final hum  = double.tryParse(widget.humidity);
    final sol  = double.tryParse(widget.sol); // ← NOUVEAU
    final now  = DateTime.now();

    List<Map<String, dynamic>> newAlerts = [];

    // ── Alertes température ──────────────────────────────────────────────
    if (temp != null) {
      if (temp >= TEMP_MAX) {
        newAlerts.add(_makeAlert(
          "danger",
          "Temperature critique !",
          "Temperature trop elevee : ${temp.toStringAsFixed(1)}C (max ${TEMP_MAX}C)",
          "Arrosez immediatement. Protegez les cultures du soleil.",
          Icons.local_fire_department,
          Colors.red,
          now,
        ));
      } else if (temp >= TEMP_WARN) {
        newAlerts.add(_makeAlert(
          "warning",
          "Temperature elevee",
          "Temperature : ${temp.toStringAsFixed(1)}C — Surveillance recommandee",
          "Prevoyez un arrosage supplementaire en soiree.",
          Icons.thermostat,
          Colors.orange,
          now,
        ));
      } else if (temp <= TEMP_MIN) {
        newAlerts.add(_makeAlert(
          "danger",
          "Risque de gel !",
          "Temperature trop basse : ${temp.toStringAsFixed(1)}C (min ${TEMP_MIN}C)",
          "Couvrez les cultures. Activez le chauffage si disponible.",
          Icons.ac_unit,
          Colors.blue.shade700,
          now,
        ));
      } else {
        newAlerts.add(_makeAlert(
          "ok",
          "Temperature normale",
          "Temperature : ${temp.toStringAsFixed(1)}C — Conditions optimales",
          "Aucune action requise.",
          Icons.check_circle,
          Colors.green,
          now,
        ));
      }
    }

    // ── Alertes humidité air ─────────────────────────────────────────────
    if (hum != null) {
      if (hum >= HUM_MAX) {
        newAlerts.add(_makeAlert(
          "danger",
          "Humidite air excessive !",
          "Humidite : ${hum.toStringAsFixed(1)}% (max $HUM_MAX%)",
          "Risque de maladies fongiques. Ameliorez la ventilation.",
          Icons.water,
          Colors.red,
          now,
        ));
      } else if (hum >= HUM_WARN_H) {
        newAlerts.add(_makeAlert(
          "warning",
          "Humidite air elevee",
          "Humidite : ${hum.toStringAsFixed(1)}% — Surveillance conseillee",
          "Verifiez la ventilation pour eviter les champignons.",
          Icons.water_drop,
          Colors.orange,
          now,
        ));
      } else if (hum <= HUM_MIN) {
        newAlerts.add(_makeAlert(
          "danger",
          "Secheresse air detectee !",
          "Humidite trop faible : ${hum.toStringAsFixed(1)}% (min $HUM_MIN%)",
          "Arrosez immediatement. Verifiez le systeme d irrigation.",
          Icons.warning_amber,
          Colors.deepOrange,
          now,
        ));
      } else if (hum <= HUM_WARN_L) {
        newAlerts.add(_makeAlert(
          "warning",
          "Humidite air basse",
          "Humidite : ${hum.toStringAsFixed(1)}% — Arrosage recommande",
          "Planifiez un arrosage dans les prochaines heures.",
          Icons.opacity,
          Colors.orange,
          now,
        ));
      } else {
        newAlerts.add(_makeAlert(
          "ok",
          "Humidite air normale",
          "Humidite : ${hum.toStringAsFixed(1)}% — Conditions optimales",
          "Aucune action requise.",
          Icons.check_circle,
          Colors.green,
          now,
        ));
      }
    }

    // ── Alertes humidité sol ── NOUVEAU ──────────────────────────────────
    if (sol != null) {
      if (sol >= SOL_SEC_CRITIQUE) {
        newAlerts.add(_makeAlert(
          "danger",
          "Sol tres sec !",
          "Humidite sol critique (RAW: ${sol.toStringAsFixed(0)}) — Sol tres sec",
          "Arrosage urgent ! Les racines manquent d eau.",
          Icons.grass,
          Colors.red,
          now,
        ));
      } else if (sol >= SOL_SEC_WARN) {
        newAlerts.add(_makeAlert(
          "warning",
          "Sol sec",
          "Humidite sol faible (RAW: ${sol.toStringAsFixed(0)}) — Arrosage recommande",
          "Planifiez un arrosage dans les prochaines heures.",
          Icons.grass,
          Colors.orange,
          now,
        ));
      } else if (sol <= SOL_HUMIDE_MAX) {
        newAlerts.add(_makeAlert(
          "danger",
          "Sol sature !",
          "Humidite sol excessive (RAW: ${sol.toStringAsFixed(0)}) — Risque de pourriture",
          "Arretez l arrosage. Verifiez le drainage du sol.",
          Icons.water_damage,
          Colors.indigo,
          now,
        ));
      } else if (sol <= SOL_HUMIDE_WARN) {
        newAlerts.add(_makeAlert(
          "warning",
          "Sol tres humide",
          "Humidite sol elevee (RAW: ${sol.toStringAsFixed(0)}) — Surveillance conseillee",
          "Reduisez l arrosage. Surveillez l apparition de moisissures.",
          Icons.water_damage_outlined,
          Colors.blue,
          now,
        ));
      } else {
        newAlerts.add(_makeAlert(
          "ok",
          "Sol en bon etat",
          "Humidite sol correcte (RAW: ${sol.toStringAsFixed(0)}) — Conditions ideales",
          "Aucune action requise pour le sol.",
          Icons.spa,
          Colors.green,
          now,
        ));
      }
    }

    // ── Alerte combinée : chaleur + humidité basse = stress hydrique ──
    if (temp != null && hum != null &&
        temp >= TEMP_WARN && hum <= HUM_WARN_L) {
      newAlerts.add(_makeAlert(
        "danger",
        "Stress hydrique !",
        "Chaleur (${temp.toStringAsFixed(1)}C) + faible humidite (${hum.toStringAsFixed(1)}%)",
        "Danger immédiat pour les cultures. Arrosage urgent necessaire.",
        Icons.warning_rounded,
        Colors.deepOrange,
        now,
      ));
    }

    // ── Alerte combinée : sol sec + chaleur ── NOUVEAU
    if (temp != null && sol != null &&
        temp >= TEMP_WARN && sol >= SOL_SEC_WARN) {
      newAlerts.add(_makeAlert(
        "danger",
        "Sol sec + chaleur !",
        "Sol sec (RAW: ${sol.toStringAsFixed(0)}) + temp ${temp.toStringAsFixed(1)}C",
        "Double danger ! Arrosage immediat indispensable.",
        Icons.local_fire_department,
        Colors.deepOrange,
        now,
      ));
    }

    if (!mounted) return;
    setState(() {
      for (final alert in newAlerts) {
        alertHistory.insert(0, alert);
      }
      if (alertHistory.length > 50) {
        alertHistory = alertHistory.sublist(0, 50);
      }
    });
  }

  Map<String, dynamic> _makeAlert(
    String type,
    String title,
    String message,
    String conseil,
    IconData icon,
    Color color,
    DateTime time,
  ) {
    return {
      'type':    type,
      'title':   title,
      'message': message,
      'conseil': conseil,
      'icon':    icon,
      'color':   color,
      'time':    time,
    };
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')}:"
        "${dt.second.toString().padLeft(2, '0')}";
  }

  // Statut global incluant le sol
  String get _globalStatus {
    final temp = double.tryParse(widget.temperature);
    final hum  = double.tryParse(widget.humidity);
    final sol  = double.tryParse(widget.sol); // ← NOUVEAU

    if (temp == null || hum == null) return "unknown";

    if (temp >= TEMP_MAX || temp <= TEMP_MIN ||
        hum  >= HUM_MAX  || hum  <= HUM_MIN  ||
        (sol != null && (sol >= SOL_SEC_CRITIQUE || sol <= SOL_HUMIDE_MAX)))
      return "danger";

    if (temp >= TEMP_WARN || hum >= HUM_WARN_H || hum <= HUM_WARN_L ||
        (sol != null && (sol >= SOL_SEC_WARN || sol <= SOL_HUMIDE_WARN)))
      return "warning";

    return "ok";
  }

  // Label état sol ── NOUVEAU
  String _solStatus(double? sol) {
    if (sol == null) return "--";
    if (sol >= SOL_SEC_CRITIQUE) return "Tres sec";
    if (sol >= SOL_SEC_WARN)     return "Sec";
    if (sol <= SOL_HUMIDE_MAX)   return "Sature";
    if (sol <= SOL_HUMIDE_WARN)  return "Tres humide";
    return "Normal";
  }

  @override
  Widget build(BuildContext context) {
    final status      = _globalStatus;
    final sol         = double.tryParse(widget.sol);
    final statusColor = status == "danger"
        ? Colors.red
        : status == "warning"
            ? Colors.orange
            : Colors.green;
    final statusText = status == "danger"
        ? "ALERTE CRITIQUE"
        : status == "warning"
            ? "ATTENTION"
            : "TOUT VA BIEN";
    final statusIcon = status == "danger"
        ? Icons.warning_rounded
        : status == "warning"
            ? Icons.info_rounded
            : Icons.check_circle_rounded;

    return Column(
      children: [
        // ── Bannière statut global ──
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: statusColor,
          child: Row(
            children: [
              Icon(statusIcon, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      "Temp: ${widget.temperature == '--' ? '--' : '${widget.temperature}C'}   "
                      "Hum: ${widget.humidity == '--' ? '--' : '${widget.humidity}%'}   "
                      "Sol: ${_solStatus(sol)}", // ← NOUVEAU
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white38),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 8),
                    SizedBox(width: 4),
                    Text("LIVE",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Seuils de référence ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              // Ligne 1 : temp + hum
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _thresholdBadge("Temp max", "${TEMP_MAX}C", Colors.red),
                  _thresholdBadge("Temp min", "${TEMP_MIN}C", Colors.blue),
                  _thresholdBadge("Hum max",  "$HUM_MAX%",   Colors.red),
                  _thresholdBadge("Hum min",  "$HUM_MIN%",   Colors.orange),
                ],
              ),
              const SizedBox(height: 8),
              // Ligne 2 : sol ── NOUVEAU
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _thresholdBadge("Sol sec",     ">$SOL_SEC_CRITIQUE",  Colors.red),
                  _thresholdBadge("Sol normal", "$SOL_HUMIDE_WARN-$SOL_SEC_WARN", Colors.green),
                  _thresholdBadge("Sol humide", "<$SOL_HUMIDE_WARN",   Colors.blue),
                  _thresholdBadge("Sol sature", "<$SOL_HUMIDE_MAX",    Colors.indigo),
                ],
              ),
            ],
          ),
        ),

        // ── Titre historique ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Historique des alertes (${alertHistory.length})",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (alertHistory.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() => alertHistory.clear()),
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.red),
                  label: const Text("Effacer",
                      style:
                          TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
        ),

        // ── Liste alertes ──
        Expanded(
          child: alertHistory.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text("En attente de donnees...",
                          style: TextStyle(
                              fontSize: 15, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  itemCount: alertHistory.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final alert   = alertHistory[index];
                    final color   = alert['color'] as Color;
                    final isLatest = index == 0;

                    return Container(
                      decoration: BoxDecoration(
                        color: isLatest
                            ? color.withOpacity(0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isLatest
                              ? color.withOpacity(0.4)
                              : Colors.grey.shade200,
                          width: isLatest ? 1.5 : 1,
                        ),
                        boxShadow: isLatest
                            ? [BoxShadow(
                                color: color.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )]
                            : [],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.15),
                          child: Icon(alert['icon'] as IconData,
                              color: color, size: 22),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                alert['title'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: color,
                                ),
                              ),
                            ),
                            if (isLatest)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: const Text("Nouveau",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(alert['message'] as String,
                                style:
                                    const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.tips_and_updates,
                                    size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    alert['conseil'] as String,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(
                                  alert['time'] as DateTime),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _thresholdBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(value,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}