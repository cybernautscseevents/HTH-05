/// ============================================================================
/// ⚠️ TEMPORARY TEST-ONLY LOGIN — DELETE BEFORE ANY REAL DEPLOYMENT
/// ============================================================================
///
/// Lets the linking flow be tested end to end while the receptionist/doctor
/// web app that issues real activation codes does not exist yet. Nothing here
/// touches the backend — it works with the API completely offline.
///
///   Patient ID   : SAA-TEST-0001
///   6-digit code : 123456
///   QR payload   : saathi://link?token=SAATHI-TEST-QR
///
/// HOW TO REMOVE (three steps, all greppable for "test_login" or "TEST-ONLY")
///   1. Delete this file.
///   2. Delete the three `testLogin*` guards in lib/src/app_controller.dart —
///      one in `initialize`, one in `linkWithQr`, one in `_link`. Each is a
///      single early-return block marked with the same warning banner.
///   3. Delete the import of this file from app_controller.dart.
///
/// Nothing else in the app references these values, and no screen knows this
/// file exists — the real and test paths converge on the same AppController
/// state, so what you see when testing is exactly what a real link produces.
/// ============================================================================
library;

import '../models.dart';

/// TEST-ONLY. The unique patient ID to type on the "Link with unique ID"
/// screen.
const kTestPatientUid = 'SAA-TEST-0001';

/// TEST-ONLY. The 6-digit activation code to type alongside it.
const kTestActivationCode = '123456';

/// TEST-ONLY. Encode this exact string in any QR generator and point the scan
/// screen at it. It matches the `saathi://` scheme the real activation QR uses.
const kTestQrPayload = 'saathi://link?token=SAATHI-TEST-QR';

/// TEST-ONLY. Stored in secure storage in place of a real device token so the
/// app reopens straight into the linked state instead of dropping to the
/// "cannot reach the hospital" screen on the next launch.
const kTestDeviceToken = 'TEST-ONLY-DEVICE-TOKEN-DELETE-ME';

/// TEST-ONLY. The fake patient record the test credentials resolve to.
///
/// Deliberately named "Test Patient" rather than something realistic: a
/// fabricated record in a medical app must never be mistakable for a real
/// person. The condition is a real clinical string so the local disease-name
/// mapping is exercised — it renders as "Sugar illness (diabetes)".
const kTestPatient = Patient(
  id: -1,
  uid: kTestPatientUid,
  name: 'Test Patient',
  age: 62,
  condition: 'Type 2 Diabetes Mellitus',
  phone: null,
  receptionistName: 'Receptionist',
  currentMedicines: null,
);

/// TEST-ONLY. True when the typed ID and code match the test credentials.
bool testLoginMatchesCredentials(String? patientUid, String? activationCode) {
  final uid = patientUid?.trim().toUpperCase();
  return (uid == kTestPatientUid || uid == '1' || uid == '-1') &&
      activationCode?.trim() == kTestActivationCode;
}

/// TEST-ONLY. True when a scanned QR carried the test activation token.
bool testLoginMatchesQrToken(String? qrToken) =>
    qrToken == Uri.parse(kTestQrPayload).queryParameters['token'];

/// TEST-ONLY. True when the stored device token is the fake one written by a
/// previous test link.
bool testLoginMatchesStoredToken(String? deviceToken) =>
    deviceToken == kTestDeviceToken;
