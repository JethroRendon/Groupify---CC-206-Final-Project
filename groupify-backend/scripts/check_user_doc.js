require('dotenv').config();
const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

async function main() {
  try {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id,
    });

    const db = admin.firestore();

    const uid = process.argv[2] || '';
    if (!uid) {
      console.error('Usage: node check_user_doc.js <uid>');
      process.exit(1);
    }

    console.log('Checking Firestore for user doc with ID:', uid);

    const docRef = db.collection('users').doc(uid);
    const doc = await docRef.get();

    if (!doc.exists) {
      console.log('Result: User document NOT found for UID:', uid);
      process.exit(0);
    }

    console.log('Result: User document FOUND for UID:', uid);
    console.log('Document data:', JSON.stringify(doc.data(), null, 2));
    process.exit(0);

  } catch (err) {
    console.error('Error checking user doc:', err);
    process.exit(2);
  }
}

main();
