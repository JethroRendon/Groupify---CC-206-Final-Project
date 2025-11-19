// routes/notifications.js
const express = require('express');
const { db, admin } = require('../config/firebase');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();
const NOTIFICATIONS_COLLECTION = 'notifications';

// ============================================
// CREATE NOTIFICATION
// ============================================
router.post('/create', authenticateToken, async (req, res) => {
  try {
    const { userId, type, title, message, groupId, taskId } = req.body;

    if (!userId || !type || !title || !message) {
      return res.status(400).json({ 
        success: false,
        error: 'userId, type, title, and message are required' 
      });
    }

    const notificationData = {
      userId,
      type,
      title,
      message,
      groupId: groupId || null,
      taskId: taskId || null,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    const notifRef = await db.collection(NOTIFICATIONS_COLLECTION).add(notificationData);

    res.status(201).json({
      success: true,
      message: 'Notification created',
      notification: {
        id: notifRef.id,
        ...notificationData,
        createdAt: new Date().toISOString()
      }
    });

  } catch (error) {
    console.error('Create notification error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// GET USER NOTIFICATIONS
// ============================================
router.get('/my-notifications', authenticateToken, async (req, res) => {
  try {
    const { unreadOnly } = req.query;

    let query = db.collection(NOTIFICATIONS_COLLECTION)
      .where('userId', '==', req.user.uid);
    
    if (unreadOnly === 'true') {
      query = query.where('isRead', '==', false);
    }

    const notificationsSnapshot = await query
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();

    const notifications = [];
    notificationsSnapshot.forEach(doc => {
      notifications.push({
        id: doc.id,
        ...doc.data()
      });
    });

    res.status(200).json({
      success: true,
      count: notifications.length,
      notifications
    });

  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// MARK NOTIFICATION AS READ
// ============================================
router.put('/:notificationId/read', authenticateToken, async (req, res) => {
  try {
    const { notificationId } = req.params;
    const notifDoc = await db.collection(NOTIFICATIONS_COLLECTION).doc(notificationId).get();

    if (!notifDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'Notification not found' 
      });
    }

    const notifData = notifDoc.data();

    if (notifData.userId !== req.user.uid) {
      return res.status(403).json({ 
        success: false,
        error: 'Access denied' 
      });
    }

    await db.collection(NOTIFICATIONS_COLLECTION).doc(notificationId).update({
      isRead: true
    });

    res.status(200).json({
      success: true,
      message: 'Notification marked as read'
    });

  } catch (error) {
    console.error('Mark notification read error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// MARK ALL AS READ
// ============================================
router.put('/mark-all-read', authenticateToken, async (req, res) => {
  try {
    const notificationsSnapshot = await db.collection(NOTIFICATIONS_COLLECTION)
      .where('userId', '==', req.user.uid)
      .where('isRead', '==', false)
      .get();

    const batch = db.batch();
    notificationsSnapshot.forEach(doc => {
      batch.update(doc.ref, { isRead: true });
    });
    await batch.commit();

    res.status(200).json({
      success: true,
      message: `${notificationsSnapshot.size} notifications marked as read`
    });

  } catch (error) {
    console.error('Mark all read error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// DELETE NOTIFICATION
// ============================================
router.delete('/:notificationId', authenticateToken, async (req, res) => {
  try {
    const { notificationId } = req.params;
    const notifDoc = await db.collection(NOTIFICATIONS_COLLECTION).doc(notificationId).get();

    if (!notifDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'Notification not found' 
      });
    }

    const notifData = notifDoc.data();

    if (notifData.userId !== req.user.uid) {
      return res.status(403).json({ 
        success: false,
        error: 'Access denied' 
      });
    }

    await db.collection(NOTIFICATIONS_COLLECTION).doc(notificationId).delete();

    res.status(200).json({
      success: true,
      message: 'Notification deleted'
    });

  } catch (error) {
    console.error('Delete notification error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

module.exports = router;