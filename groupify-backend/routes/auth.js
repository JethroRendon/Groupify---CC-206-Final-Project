const express = require('express');
const { auth, db, collections } = require('../config/firebase');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// ============================================
// SIGN UP - After Onboarding Screens
// ============================================
router.post('/signup', async (req, res) => {
  try {
    const { fullName, email, password, school, course, yearLevel, section } = req.body;

    // Validation
    if (!fullName || !email || !password || !school || !course || !yearLevel || !section) {
      return res.status(400).json({ 
        success: false,
        error: 'All fields are required'
      });
    }

    // Email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ 
        success: false,
        error: 'Invalid email format' 
      });
    }

    // Password validation
    if (password.length < 8) {
      return res.status(400).json({ 
        success: false,
        error: 'Password must be at least 8 characters' 
      });
    }

    // Create Firebase Auth user
    const userRecord = await auth.createUser({
      email: email.toLowerCase(),
      password: password,
      displayName: fullName
    });

    // Create user document in Firestore
    const userData = {
      uid: userRecord.uid,
      fullName,
      email: email.toLowerCase(),
      school,
      course,
      yearLevel,
      section,
      hasSeenOnboarding: true,  // They just completed onboarding
      createdAt: new Date().toISOString(),
      lastLogin: new Date().toISOString()
    };

    await db.collection(collections.USERS).doc(userRecord.uid).set(userData);

    // Generate custom token (optional - client can sign in directly)
    const customToken = await auth.createCustomToken(userRecord.uid);

    // Return success - redirect to Home
    res.status(201).json({
      success: true,
      message: 'Account created successfully',
      customToken,  // Client uses this to sign in with Firebase
      user: {
        uid: userRecord.uid,
        fullName,
        email: email.toLowerCase(),
        school,
        course,
        yearLevel,
        section,
        hasSeenOnboarding: true
      },
      redirectTo: 'home'  // Go directly to home after signup
    });

  } catch (error) {
    console.error('Signup error:', error);
    
    // Handle Firebase-specific errors
    if (error.code === 'auth/email-already-exists') {
      return res.status(409).json({ 
        success: false,
        error: 'User already exists with this email' 
      });
    }
    
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
  try {
    // Get user data from Firestore
    const userDoc = await db.collection(collections.USERS).doc(req.user.uid).get();
    
    if (!userDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'User not found',
        requiresAuth: true
      });
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