import 'package:firebase_core/firebase_core.dart';

Future<FirebaseApp> initializeFirebase() async {
  const firebaseConfig = {
    'apiKey': "AIzaSyBNoDsveT7eA067dqDSO7IWFKXiu52Kdfc",
    'authDomain': "expyr-ai.firebaseapp.com",
    'projectId': "expyr-ai",
    'storageBucket': "expyr-ai.firebasestorage.app",
    'messagingSenderId': "164281328122",
    'appId': "1:164281328122:web:41986711ca31cdfe430443",
  };

  return await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: firebaseConfig['apiKey'] ?? '',
      authDomain: firebaseConfig['authDomain'] ?? '',
      projectId: firebaseConfig['projectId'] ?? '',
      storageBucket: firebaseConfig['storageBucket'] ?? '',
      messagingSenderId: firebaseConfig['messagingSenderId'] ?? '',
      appId: firebaseConfig['appId'] ?? '',
    ),
  );
}
