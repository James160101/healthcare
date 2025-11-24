import 'package:flutter/foundation.dart';

class AiService extends ChangeNotifier {
  // Simulation d'une analyse IA.
  // À terme, cela appellerait une API comme Google Gemini (Vertex AI) ou OpenAI.
  
  bool _isLoading = false;
  String _latestInsight = "Aucune analyse récente.";

  bool get isLoading => _isLoading;
  String get latestInsight => _latestInsight;

  /// Analyse les données vitales pour fournir un conseil de santé
  Future<void> analyzeVitals({required int heartRate, double? temperature}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Simulation d'un délai réseau (appel API)
      await Future.delayed(const Duration(seconds: 2));

      // Logique simple pour simuler une réponse IA basée sur les données
      if (heartRate > 100) {
        _latestInsight = "Attention : Votre fréquence cardiaque est élevée (${heartRate} bpm). "
            "L'IA suggère une période de calme. Si vous n'êtes pas en exercice, "
            "hydratez-vous et respirez profondément.";
      } else if (heartRate < 60) {
        _latestInsight = "Note : Votre fréquence cardiaque est basse (${heartRate} bpm). "
            "C'est souvent signe d'une bonne condition physique chez les sportifs, "
            "mais surveillez si vous ressentez de la fatigue.";
      } else {
        _latestInsight = "Analyse IA : Vos paramètres vitaux sont dans la norme. "
            "Maintenez votre routine actuelle.";
      }
      
    } catch (e) {
      _latestInsight = "Erreur lors de l'analyse IA : $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Génère un résumé hebdomadaire (Simulation)
  Future<String> getWeeklySummary() async {
    await Future.delayed(const Duration(seconds: 1));
    return "Cette semaine, votre santé cardiaque a été stable. "
           "Aucune anomalie majeure détectée par l'algorithme.";
  }
}
