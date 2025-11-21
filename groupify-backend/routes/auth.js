const express = require('express');
const { auth, db, collections } = require('../config/firebase');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();


// SIGN UP - After Onboarding Screens

router.post('/signup', authenticateToken, async (req, res) => {
  try {
    const { fullName, email, password, school, course, yearLevel, section } = req.body;

    console.log('📝 Signup request received');
    console.log('Headers:', JSON.stringify(req.headers));
    console.log('Body:', JSON.stringify(req.body));
    console.log('👤 Authenticated user UID:', req.user && req.user.uid);

    // Validation
    if (!fullName || !email || !school || !course || !yearLevel || !section) {
      return res.status(400).json({ 
        success: false,
        error: 'All fields are required'
      });
    }

    // Create user document in Firestore using authenticated UID
    const userData = {
      uid: req.user.uid,
      fullName,
      email: email.toLowerCase(),
      school,
      course,
      yearLevel,
      section,
      hasSeenOnboarding: true,
      groupIds: [], // Initialize empty array
      createdAt: new Date().toISOString(),
      lastLogin: new Date().toISOString()
    };

    await db.collection(collections.USERS).doc(req.user.uid).set(userData);
    console.log('✅ User document created in Firestore for UID:', req.user.uid);

    // Return success
    res.status(201).json({
      success: true,
      message: 'Account created successfully',
      user: {
        uid: req.user.uid,
        fullName,
        email: email.toLowerCase(),
        school,
        course,
        yearLevel,
        section,
        hasSeenOnboarding: true
      },
      redirectTo: 'home'
    });

  } catch (error) {
    console.error('❌ Signup error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error: ' + error.message 
    });
  }
});

// ============================================
// SIGN IN - Firebase Authentication
// ============================================
router.post('/signin', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Email and password are required'
      });
    }

    // NOTE: The Admin SDK (your backend) cannot directly verify passwords.
    // Sign-in with password should happen in the client using Firebase Auth.
    // However, we can help the client by generating a custom token if the user exists.

    const userRecord = await auth.getUserByEmail(email.toLowerCase()).catch(() => null);

    if (!userRecord) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    // Generate a custom Firebase token (client uses this to authenticate)
    const customToken = await auth.createCustomToken(userRecord.uid);

    res.status(200).json({
      success: true,
      message: 'User found, use this token to sign in with Firebase on the client',
      customToken,
      user: {
        uid: userRecord.uid,
        email: userRecord.email,
        displayName: userRecord.displayName || null
      }
    });

  } catch (error) {
    console.error('Sign-in error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
});


// ============================================
// VERIFY USER - Check Firebase Token
// ============================================
router.get('/verify', authenticateToken, async (req, res) => {
  console.log('GET /api/auth/verify called for uid:', req.user && req.user.uid);
  console.log('Request headers (verify):', JSON.stringify(req.headers));
  try {
    // Get user data from Firestore
    let userDoc = await db.collection(collections.USERS).doc(req.user.uid).get();

    // If no Firestore document, attempt to create one from Firebase Auth record
    if (!userDoc.exists) {
      console.log('User doc not found for UID:', req.user.uid, '- attempting to create from Firebase Auth record');
      try {
        const userRecord = await auth.getUser(req.user.uid);
        const userDataFromAuth = {
          uid: req.user.uid,
          fullName: userRecord.displayName || '',
          email: userRecord.email || '',
          school: '',
          course: '',
          yearLevel: '',
          section: '',
          hasSeenOnboarding: true,
          groupIds: [],
          createdAt: new Date().toISOString(),
          lastLogin: new Date().toISOString()
        };

        await db.collection(collections.USERS).doc(req.user.uid).set(userDataFromAuth);
        console.log('✅ Created Firestore user doc for UID from Auth:', req.user.uid);

        // Refresh userDoc reference
        userDoc = await db.collection(collections.USERS).doc(req.user.uid).get();
      } catch (err) {
        console.error('Error creating user doc from Auth for UID', req.user.uid, err);
        return res.status(500).json({ success: false, error: 'Internal server error' });
      }
    }

    const userData = userDoc.data();

    // Update last login
    await db.collection(collections.USERS).doc(req.user.uid).update({
      lastLogin: new Date().toISOString()
    });

    res.status(200).json({
      success: true,
      message: 'Token valid',
      user: {
        uid: userData.uid,
        fullName: userData.fullName,
        email: userData.email,
        school: userData.school,
        course: userData.course,
        yearLevel: userData.yearLevel,
        section: userData.section,
        hasSeenOnboarding: userData.hasSeenOnboarding || false
      },
      // Returning users skip onboarding
      redirectTo: userData.hasSeenOnboarding ? 'home' : 'onboarding'
    });

  } catch (error) {
    console.error('Verify error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// MARK ONBOARDING AS SEEN (Optional)
// ============================================
router.post('/complete-onboarding', authenticateToken, async (req, res) => {
  try {
    await db.collection(collections.USERS).doc(req.user.uid).update({
      hasSeenOnboarding: true
    });

    res.status(200).json({
      success: true,
      message: 'Onboarding completed',
      user: {
        uid: req.user.uid,
        hasSeenOnboarding: true
      }
    });

  } catch (error) {
    console.error('Onboarding error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// UPDATE USER EMAIL (Admin SDK)
// ============================================
router.put('/update-email', authenticateToken, async (req, res) => {
  try {
    const { newEmail } = req.body;

    if (!newEmail) {
      return res.status(400).json({ 
        success: false,
        error: 'New email is required' 
      });
    }

    // Update Firebase Auth email
    await auth.updateUser(req.user.uid, {
      email: newEmail.toLowerCase()
    });

    // Update Firestore
    await db.collection(collections.USERS).doc(req.user.uid).update({
      email: newEmail.toLowerCase()
    });

    res.status(200).json({
      success: true,
      message: 'Email updated successfully',
      email: newEmail.toLowerCase()
    });

  } catch (error) {
    console.error('Update email error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// DELETE USER ACCOUNT
// ============================================
router.delete('/delete-account', authenticateToken, async (req, res) => {
  try {
    // Delete from Firestore
    await db.collection(collections.USERS).doc(req.user.uid).delete();

    // Delete from Firebase Auth
    await auth.deleteUser(req.user.uid);

    res.status(200).json({
      success: true,
      message: 'Account deleted successfully',
      redirectTo: 'signin'
    });

  } catch (error) {
    console.error('Delete account error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

module.exports = router;

// ----------------------
// DEV-ONLY: test signup without auth (helps simulate client requests locally)
// ----------------------
if (process.env.NODE_ENV !== 'production') {
  router.post('/test-signup', async (req, res) => {
    try {
      const { uid, fullName, email, school, course, yearLevel, section } = req.body;
      console.log('DEV test-signup called. Body:', JSON.stringify(req.body));

      if (!uid || !fullName || !email) {
        return res.status(400).json({ success: false, error: 'uid, fullName and email are required for test-signup' });
      }

      const userData = {
        uid,
        fullName,
        email: email.toLowerCase(),
        school: school || '',
        course: course || '',
        yearLevel: yearLevel || '',
        section: section || '',
        hasSeenOnboarding: true,
        groupIds: [],
        createdAt: new Date().toISOString(),
        lastLogin: new Date().toISOString()
      };

      await db.collection(collections.USERS).doc(uid).set(userData);
      console.log('✅ DEV: created user doc for', uid);

      res.status(201).json({ success: true, message: 'DEV: user created', user: userData });
    } catch (err) {
      console.error('DEV test-signup error:', err);
      res.status(500).json({ success: false, error: 'Internal server error' });
    }
  });
  
  // DEV-only: verify by uid without token (helps simulate client verify on local)
  router.post('/dev-verify', async (req, res) => {
    try {
      const { uid } = req.body;
      console.log('DEV dev-verify called for uid:', uid);
      if (!uid) return res.status(400).json({ success: false, error: 'uid required' });

      const userDoc = await db.collection(collections.USERS).doc(uid).get();
      if (!userDoc.exists) {
        return res.status(404).json({ success: false, error: 'User not found' });
      }

      const userData = userDoc.data();
      const redirectTo = userData.hasSeenOnboarding ? 'home' : 'onboarding';

      return res.status(200).json({ success: true, redirectTo, user: userData });
    } catch (err) {
      console.error('DEV dev-verify error:', err);
      return res.status(500).json({ success: false, error: 'Internal server error' });
    }
  });
}