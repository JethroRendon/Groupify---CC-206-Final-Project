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
      console.error('Usage: node create_user_doc.js <uid> [email] [fullName]');
      process.exit(1);
    }

    const email = process.argv[3] || `${uid}@example.com`;
    const fullName = process.argv[4] || 'New User';

    const docRef = db.collection('users').doc(uid);
    const now = admin.firestore.FieldValue.serverTimestamp();

    const data = {
      uid,
      email,
      fullName,
      school: '',
      course: '',
      yearLevel: '',
      section: '',
      hasSeenOnboarding: false,
      createdAt: now,
      lastLogin: now
    };

    await docRef.set(data, { merge: true });

    console.log('Created/Updated user document for UID:', uid);
    process.exit(0);
  } catch (err) {
    console.error('Error creating user doc:', err);
    process.exit(2);
  }
}

main();
