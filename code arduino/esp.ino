#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <Wire.h>
#include "MAX30105.h"
#include "heartRate.h"
#include <time.h>

#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// Configuration WiFi
#define WIFI_SSID "James"
#define WIFI_PASSWORD "215301018329"

// Configuration Firebase
#define API_KEY "AIzaSyDPJrKBdUREgRAljMbDIIuMo7gsLDHNlM8"
#define DATABASE_URL "https://cardiaque-cdfa4-default-rtdb.firebaseio.com/"
#define USER_EMAIL "josemswernerlodwige@gmail.com"
#define USER_PASSWORD "16Janvier2001@gmail.com"

// Objets Firebase
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

unsigned long sendDataPrevMillis = 0;
bool signupOK = false;

// Capteur MAX30102
MAX30105 particleSensor;

// Variables pour la fréquence cardiaque
const byte RATE_SIZE = 4;
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0;
float beatsPerMinute;
int beatAvg;

// Variables pour SpO2
double avered = 0;
double aveir = 0;
int i = 0;
int Num = 100;
#define FINGER_ON 30000
#define MINIMUM_SPO2 90.0

float spo2 = 0;
float ESpO2 = 95.0;
float FSpO2 = 0.7;
double SpO2_value;

String patientID = "PATIENT_001";

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=================================");
  Serial.println("Surveillance Cardiaque ESP32");
  Serial.println("=================================\n");
  
  // Connexion WiFi
  Serial.print("Connexion WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(500);
  }
  
  Serial.println("\n✓ WiFi connecté!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
  
  // Configuration NTP
  configTime(0, 0, "pool.ntp.org");
  
  // Configuration Firebase
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback;
  
  Serial.println("\nConnexion à Firebase...");
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  // Attendre l'authentification
  int timeout = 0;
  while (!Firebase.ready() && timeout < 30) {
    Serial.print(".");
    delay(1000);
    timeout++;
  }
  
  if (Firebase.ready()) {
    Serial.println("\n✓ Firebase connecté!");
    signupOK = true;
  } else {
    Serial.println("\n✗ Erreur Firebase!");
    Serial.println("Vérifiez l'authentification dans Firebase Console");
  }
  
  // Initialisation MAX30102
  Serial.println("\nInitialisation du capteur...");
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("✗ MAX30102 non détecté!");
    Serial.println("Vérifiez les connexions:");
    Serial.println("  VIN → 3.3V");
    Serial.println("  GND → GND");
    Serial.println("  SDA → GPIO 21");
    Serial.println("  SCL → GPIO 22");
    while (1);
  }
  
  Serial.println("✓ MAX30102 détecté!");
  
  // Configuration du capteur avec paramètres optimisés
  byte ledBrightness = 0x7F;
  byte sampleAverage = 4;
  byte ledMode = 2;
  int sampleRate = 100;
  int pulseWidth = 411;
  int adcRange = 4096;
  
  particleSensor.setup(ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange);
  particleSensor.setPulseAmplitudeRed(0x1F);
  particleSensor.setPulseAmplitudeIR(0x1F);
  
  Serial.println("\n=== Placez votre doigt sur le capteur ===\n");
}

void loop() {
  long irValue = particleSensor.getIR();
  long redValue = particleSensor.getRed();
  
  // Afficher les valeurs brutes pour diagnostic
  static unsigned long lastPrint = 0;
  if (millis() - lastPrint > 2000) {
    lastPrint = millis();
    Serial.print("IR: ");
    Serial.print(irValue);
    Serial.print(" | Red: ");
    Serial.println(redValue);
  }
  
  if (irValue > FINGER_ON) {
    // Méthode alternative de détection de battements
    static long lastIRValue = 0;
    static long peakIR = 0;
    static long valleyIR = 999999;
    static unsigned long lastBeatTime = 0;
    static int beatCount = 0;
    static unsigned long beatStartTime = millis();
    
    // Mettre à jour min/max
    if (irValue > peakIR) peakIR = irValue;
    if (irValue < valleyIR) valleyIR = irValue;
    
    // Détecter un pic (battement)
    long threshold = (peakIR + valleyIR) / 2;
    if (lastIRValue < threshold && irValue >= threshold) {
      unsigned long currentTime = millis();
      unsigned long beatInterval = currentTime - lastBeatTime;
      
      if (beatInterval > 300 && beatInterval < 2000) {
        beatCount++;
        beatsPerMinute = 60000.0 / beatInterval;
        
        rates[rateSpot++] = (byte)beatsPerMinute;
        rateSpot %= RATE_SIZE;
        
        beatAvg = 0;
        for (byte x = 0; x < RATE_SIZE; x++)
          beatAvg += rates[x];
        beatAvg /= RATE_SIZE;
        
        Serial.println("💓 Battement détecté!");
      }
      
      lastBeatTime = currentTime;
    }
    
    lastIRValue = irValue;
    
    // Réinitialiser min/max toutes les 3 secondes
    if (millis() - beatStartTime > 3000) {
      peakIR = irValue;
      valleyIR = irValue;
      beatStartTime = millis();
    }
    
    // Calcul SpO2
    if (i < Num) {
      avered += redValue;
      aveir += irValue;
      i++;
    } else {
      avered = avered / Num;
      aveir = aveir / Num;
      
      double R = (avered / aveir);
      SpO2_value = -23.3 * (R - 0.4) + 100;
      
      if (SpO2_value > 100) SpO2_value = 100;
      if (SpO2_value < 0) SpO2_value = 0;
      
      ESpO2 = FSpO2 * ESpO2 + (1.0 - FSpO2) * SpO2_value;
      
      if (ESpO2 <= MINIMUM_SPO2) ESpO2 = MINIMUM_SPO2;
      if (ESpO2 > 100) ESpO2 = 100;
      
      spo2 = ESpO2;
      
      avered = 0;
      aveir = 0;
      i = 0;
    }
    
    Serial.print("❤️  BPM: ");
    Serial.print(beatAvg);
    Serial.print(" | 🩸 SpO2: ");
    Serial.print(spo2, 1);
    Serial.println("%");
    
    // Envoi Firebase toutes les 5 secondes
    if (Firebase.ready() && signupOK && (millis() - sendDataPrevMillis > 5000 || sendDataPrevMillis == 0)) {
      sendDataPrevMillis = millis();
      
      if (beatAvg > 0) {
        sendToFirebase(beatAvg, spo2);
      }
    }
    
  } else {
    Serial.println("⏳ Aucun doigt détecté...");
    beatAvg = 0;
    spo2 = 0;
    delay(1000);
  }
  
  delay(100);
}

void sendToFirebase(int heartRate, float spo2Value) {
  Serial.println("\n📤 Envoi à Firebase...");
  
  time_t now = time(nullptr);
  String path = "/patients/" + patientID + "/measurements/" + String(now);
  
  FirebaseJson json;
  json.set("heartRate", heartRate);
  json.set("spo2", spo2Value);
  json.set("timestamp", (int)now);
  
  String status = "Normal";
  if (heartRate < 60 || heartRate > 100) status = "Anormal";
  if (spo2Value < 95) status = "Critique";
  json.set("status", status);
  
  if (Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json)) {
    Serial.println("✓ Données envoyées!");
    
    // Mise à jour des dernières valeurs
    String latestPath = "/patients/" + patientID + "/latest";
    Firebase.RTDB.setInt(&fbdo, (latestPath + "/heartRate").c_str(), heartRate);
    Firebase.RTDB.setFloat(&fbdo, (latestPath + "/spo2").c_str(), spo2Value);
    Firebase.RTDB.setString(&fbdo, (latestPath + "/status").c_str(), status);
    Firebase.RTDB.setInt(&fbdo, (latestPath + "/timestamp").c_str(), (int)now);
    
  } else {
    Serial.println("✗ Erreur: " + fbdo.errorReason());
  }
}