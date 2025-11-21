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
    console.log('[Activity][List] groupId=', groupId, 'limit=', limit);

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

    // Fetch unsorted, then sort in memory to avoid index issues
    const activitiesSnapshot = await db.collection(ACTIVITY_LOGS_COLLECTION)
      .where('groupId', '==', groupId)
      .limit(parseInt(limit))
      .get();

    const activities = [];
    const userIds = new Set();
    activitiesSnapshot.forEach(doc => {
      const data = doc.data();
      activities.push({ id: doc.id, ...data });
      if (data.userId) userIds.add(data.userId);
      if (data.metadata && data.metadata.assigneeId) userIds.add(data.metadata.assigneeId);
      if (data.metadata && data.metadata.previousAssigneeId) userIds.add(data.metadata.previousAssigneeId);
    });

    // Sort newest first by timestamp (fallback to 0)
    activities.sort((a,b)=>{
      const ta = a.timestamp && a.timestamp.seconds ? a.timestamp.seconds * 1000 + (a.timestamp.nanoseconds||0)/1000000 : 0;
      const tb = b.timestamp && b.timestamp.seconds ? b.timestamp.seconds * 1000 + (b.timestamp.nanoseconds||0)/1000000 : 0;
      return tb - ta;
    });

    // Enrich with actor/assignee names
    const userMap = {};
    try {
      await Promise.all(Array.from(userIds).map(async uid => {
        try {
          const uDoc = await db.collection('users').doc(uid).get();
          if (uDoc.exists) {
            const u = uDoc.data() || {};
            userMap[uid] = u.fullName || u.name || u.email || 'Unknown';
          }
        } catch {}
      }));
      for (const act of activities) {
        act.actorName = userMap[act.userId] || null;
        if (act.metadata && act.metadata.assigneeId) {
          act.assigneeName = userMap[act.metadata.assigneeId] || null;
        }
        if (act.metadata && act.metadata.previousAssigneeId) {
          act.previousAssigneeName = userMap[act.metadata.previousAssigneeId] || null;
        }
      }
    } catch (e) {
      console.warn('Activity enrichment failed:', e.message);
    }

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

// ============================================
// CLEAR ACTIVITIES FOR GROUP
// ============================================
router.delete('/group/:groupId/clear', authenticateToken, async (req, res) => {
  try {
    const { groupId } = req.params;
    console.log('[Activity][Clear] groupId=', groupId);

    // Verify user membership
    const groupDoc = await db.collection(GROUPS_COLLECTION).doc(groupId).get();
    if (!groupDoc.exists) {
      return res.status(404).json({ success: false, error: 'Group not found' });
    }
    const groupData = groupDoc.data();
    if (!groupData.members.includes(req.user.uid)) {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    const snap = await db.collection(ACTIVITY_LOGS_COLLECTION).where('groupId', '==', groupId).get();
    if (snap.empty) {
      return res.status(200).json({ success: true, deleted: 0, message: 'No activities to clear' });
    }

    let deletedCount = 0;
    let batch = db.batch();
    let opCount = 0;
    snap.docs.forEach(doc => {
      batch.delete(doc.ref);
      deletedCount++;
      opCount++;
      if (opCount === 450) { // keep a safe margin under 500 limit
        batch.commit();
        batch = db.batch();
        opCount = 0;
      }
    });
    if (opCount > 0) await batch.commit();

    console.log('[Activity][Clear][Done] groupId=', groupId, 'deleted=', deletedCount);
    return res.status(200).json({ success: true, deleted: deletedCount });
  } catch (error) {
    console.error('Clear activities error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

module.exports = router;