// routes/notifications.js
const express = require('express');
const { db, admin } = require('../config/firebase');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();
const NOTIFICATIONS_COLLECTION = 'notifications';

// GET my notifications (unread first, then recent)
router.get('/my', authenticateToken, async (req, res) => {
  try {
    const uid = req.user.uid;
    // Avoid composite index requirement: fetch by userId only, then sort in memory
    const snap = await db.collection(NOTIFICATIONS_COLLECTION)
      .where('userId', '==', uid)
      .get();
    const notifications = [];
    snap.forEach(doc => notifications.push({ id: doc.id, ...doc.data() }));
    // Sort by createdAt desc, unread first
    notifications.sort((a, b) => {
      const aUnread = a.read !== true;
      const bUnread = b.read !== true;
      if (aUnread !== bUnread) return aUnread ? -1 : 1;
      const at = a.createdAt && a.createdAt.toMillis ? a.createdAt.toMillis() : 0;
      const bt = b.createdAt && b.createdAt.toMillis ? b.createdAt.toMillis() : 0;
      return bt - at;
    });
    const limited = notifications.slice(0, 50);
    res.json({ success: true, count: limited.length, notifications: limited });
  } catch (e) {
    console.error('Get notifications error:', e);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// Mark notification read
router.patch('/:id/read', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const ref = db.collection(NOTIFICATIONS_COLLECTION).doc(id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, error: 'Not found' });
    const data = doc.data();
    if (data.userId !== req.user.uid) {
      return res.status(403).json({ success: false, error: 'Forbidden' });
    }
    await ref.update({ read: true, readAt: admin.firestore.FieldValue.serverTimestamp() });
    res.json({ success: true });
  } catch (e) {
    console.error('Mark notification read error:', e);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// Clear all notifications for the user
router.delete('/clear', authenticateToken, async (req, res) => {
  try {
    const uid = req.user.uid;
    const snap = await db.collection(NOTIFICATIONS_COLLECTION)
      .where('userId', '==', uid)
      .get();
    
    if (snap.empty) {
      return res.json({ success: true, deletedCount: 0 });
    }

    const batch = db.batch();
    snap.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    res.json({ success: true, deletedCount: snap.size });
  } catch (e) {
    console.error('Clear notifications error:', e);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

module.exports = router;