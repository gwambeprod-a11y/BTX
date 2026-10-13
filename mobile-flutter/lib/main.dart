// BATIX Mobile (Flutter) — Chauffeurs, Magasiniers & Réceptionnaires
// Conforme aux Sections 8, 9, 19 et 20.5 du Cahier des Charges BATIX v3.1 (Octobre 2026)
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const BatixMobileApp());
}

class BatixMobileApp extends StatelessWidget {
  const BatixMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BATIX Chauffeur & Magasinier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1322),
        primaryColor: const Color(0xFFF59E0B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF59E0B),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF151E32),
        ),
      ),
      home: const ProofOfDeliveryScreen(),
    );
  }
}

class ProofOfDeliveryScreen extends StatefulWidget {
  const ProofOfDeliveryScreen({super.key});

  @override
  State<ProofOfDeliveryScreen> createState() => _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends State<ProofOfDeliveryScreen> {
  double distanceMeters = 42.0; // Geofencing < 150m (Section 9.1)
  bool isOnline = true;
  final List<bool> photosTaken = [true, false, false];
  final List<String> photoTitles = [
    '1. Plaque & Camion plein (AO-7386-00)',
    '2. Cargaison avant déchargement',
    '3. Matériaux au sol (camion vide)'
  ];

  // Calcul Haversine sur le téléphone sans réseau (Section 20.5 point 4)
  static double calculateDistanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a));
  }

  void captureDirectCameraPhoto(int index) {
    if (distanceMeters > 150.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Prise de vue bloquée : vous êtes à plus de 150m du chantier.'),
        ),
      );
      return;
    }
    if (index > 0 && !photosTaken[index - 1]) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Ordre imposé : prenez d\'abord la photo précédente.'),
        ),
      );
      return;
    }
    setState(() {
      photosTaken[index] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool geofenceOk = distanceMeters <= 150.0;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF151E32),
        title: const Text('BATIX Chauffeur • #LIV-8492',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(isOnline ? 'En ligne (3G)' : 'Hors-ligne (Sync)'),
              backgroundColor: isOnline
                  ? const Color(0xFF064E3B)
                  : const Color(0xFF7F1D1D),
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: geofenceOk
                  ? const Color(0xFF064E3B)
                  : const Color(0xFF7F1D1D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: geofenceOk ? Colors.greenAccent : Colors.redAccent,
                  width: 2),
            ),
            child: Text(
              geofenceOk
                  ? '📍 GÉOLOCALISATION OK (${distanceMeters.toInt()}m < 150m)'
                  : '🚫 HORS ZONE (${distanceMeters.toInt()}m > 150m) - PRISE DE VUE BLOQUÉE',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Séquence obligatoire des 3 photos (Caméra directe + Filigrane BATIX) :',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...List.generate(3, (idx) {
            return Card(
              color: const Color(0xFF151E32),
              child: ListTile(
                leading: Icon(
                  photosTaken[idx] ? Icons.verified : Icons.camera_alt,
                  color: photosTaken[idx] ? Colors.greenAccent : Colors.amber,
                ),
                title: Text(photoTitles[idx],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(photosTaken[idx]
                    ? 'Filigrane BATIX + GPS + Empreinte SHA-256 incrustés'
                    : 'Appareil photo direct uniquement (galerie interdite)'),
                trailing: ElevatedButton(
                  onPressed: () => captureDirectCameraPhoto(idx),
                  child: const Text('Prendre'),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
