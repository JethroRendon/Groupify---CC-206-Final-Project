// routes/activities.js
const express = require('express');
const { db, admin } = require('../config/firebase');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();
const ACTIVITY_LOGS_COLLECTION = 'activityLogs';
const GROUPS_COLLECTION = 'groups';

// ============================================
// CREATE ACTIVITY LOG
// ============================================
router.post('/log', authenticateToken, async (req, res) => {
  try {
    const { groupId, action, details, metadata } = req.body;

    if (!groupId || !action) {
      return res.status(400).json({ 
        success: false,
        error: 'groupId and action are required' 
      });
    }

    const activityData = {
      groupId,
      userId: req.user.uid,
      action,
      details: details || '',
      metadata: metadata || {},
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };

    const activityRef = await db.collection(ACTIVITY_LOGS_COLLECTION).add(activityData);

    res.status(201).json({
      success: true,
      message: 'Activity logged',
      activity: {
        id: activityRef.id,
        ...activityData,
        timestamp: new Date().toISOString()
      }
    });

  } catch (error) {
    console.error('Log activity error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// GET ACTIVITIES BY GROUP
// ============================================
router.get('/group/:groupId', authenticateToken, async (req, res) => {
  try {
    const { groupId } = req.params;
    const { limit = 20 } = req.query;

    // Verify user is member of group
    const groupDoc = await db.collection(GROUPS_COLLECTION).doc(groupId).get();
    if (!groupDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'Group not found' 
      });
    }

    const groupData = groupDoc.data();
    if (!groupData.members.includes(req.user.uid)) {
      return res.status(403).json({ 
        success: false,
        error: 'Access denied' 
      });
    }

    const activitiesSnapshot = await db.collection(ACTIVITY_LOGS_COLLECTION)
      .where('groupId', '==', groupId)
      .orderBy('timestamp', 'desc')
      .limit(parseInt(limit))
      .get();

    const activities = [];
    activitiesSnapshot.forEach(doc => {
      activities.push({
        id: doc.id,
        ...doc.data()
      });
    });

    res.status(200).json({
      success: true,
      count: activities.length,
      activities
    });

  } catch (error) {
    console.error('Get activities error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

module.exports = router;