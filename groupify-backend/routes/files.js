// routes/files.js
const express = require('express');
const multer = require('multer');
const { db, admin } = require('../config/firebase');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();
const FILES_COLLECTION = 'files';
const GROUPS_COLLECTION = 'groups';
const NOTIFICATIONS_COLLECTION = 'notifications';
const ACTIVITY_LOGS_COLLECTION = 'activityLogs';

// Initialize Firebase Storage bucket
const bucket = admin.storage().bucket();

// Configure multer for memory storage
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
});

async function createNotification({ userId, type, groupId, message, actorId }) {
  try {
    if (!userId) return;
    if (userId === actorId) return; // do not notify actor themselves here
    await db.collection(NOTIFICATIONS_COLLECTION).add({
      userId,
      type,
      groupId: groupId || null,
      taskId: null,
      message: message || '',
      actorId: actorId || null,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    console.warn('[Files][Notify] Failed:', e.message);
  }
}

async function logActivity({ groupId, userId, action, details, metadata }) {
  try {
    if (!groupId || !userId || !action) return;
    const payload = {
      groupId,
      userId,
      action,
      details: details || '',
      metadata: metadata || {},
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };
    const ref = await db.collection(ACTIVITY_LOGS_COLLECTION).add(payload);
    console.log('[Activity][Write] file route action=', action, 'id=', ref.id, 'groupId=', groupId);
  } catch (e) {
    console.warn('[Files][Activity] Failed:', e.message);
  }
}

// ============================================
// UPLOAD FILE
// ============================================
router.post('/upload', authenticateToken, upload.single('file'), async (req, res) => {
  console.log('[Files][Upload] uid:', req.user && req.user.uid, 'groupId:', req.body && req.body.groupId);
  try {
    const { groupId, description } = req.body;
    const file = req.file;

    if (!file) {
      return res.status(400).json({ success: false, error: 'No file uploaded' });
    }
    if (!groupId) {
      return res.status(400).json({ success: false, error: 'Group ID is required' });
    }

    // Verify membership
    const groupDoc = await db.collection(GROUPS_COLLECTION).doc(groupId).get();
    if (!groupDoc.exists) {
      return res.status(404).json({ success: false, error: 'Group not found' });
    }
    const groupData = groupDoc.data();
    if (!Array.isArray(groupData.members)) {
      console.error('[Files][Upload] Invalid members array for group', groupDoc.id, 'members:', groupData.members);
      return res.status(500).json({ success: false, error: 'Group members missing or invalid' });
    }
    if (!groupData.members.includes(req.user.uid)) {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    const timestamp = Date.now();
    const safeOriginalName = file.originalname.replace(/[^A-Za-z0-9._-]/g, '_');
    const filename = `groups/${groupId}/files/${timestamp}_${safeOriginalName}`;
    const fileUpload = bucket.file(filename);

    // Preflight bucket existence check
    try {
      const [exists] = await bucket.exists();
      if (!exists) {
        console.warn('[Files][Upload] Bucket does not exist:', bucket.name);
        return res.status(500).json({ success: false, error: `Storage bucket '${bucket.name}' not found. Create it in Firebase Console (Storage -> Get Started).` });
      }
    } catch (bucketCheckErr) {
      console.warn('[Files][Upload] Bucket existence check failed:', bucketCheckErr.message);
    }

    try {
      await fileUpload.save(file.buffer, {
        contentType: file.mimetype,
        resumable: false
      });
    } catch (saveErr) {
      console.error('[Files][Upload] save() failed:', saveErr && saveErr.message, saveErr);
      return res.status(500).json({ success: false, error: `File upload failed: ${saveErr.message || 'unknown error'}` });
    }

    // Generate signed URL (1 hour validity) instead of making public
    let signedUrl = null;
    try {
      [signedUrl] = await fileUpload.getSignedUrl({ action: 'read', expires: Date.now() + 3600 * 1000 });
    } catch (signErr) {
      console.warn('[Files][Upload] Signed URL generation failed:', signErr.message);
    }
    console.log('[Files][Upload] Stored at', filename, 'signedUrl?', !!signedUrl);

    const fileData = {
      fileName: file.originalname,
      fileType: file.mimetype,
      fileSize: file.size,
      uploadedBy: req.user.uid,
      groupId,
      description: description || '',
      storagePath: filename,
      fileUrl: null, // legacy field kept null
      uploadedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    const fileRef = await db.collection(FILES_COLLECTION).add(fileData);

    // Activity log for uploader
    await logActivity({
      groupId,
      userId: req.user.uid,
      action: 'file_uploaded',
      details: `Uploaded file: ${file.originalname}`,
      metadata: { fileId: fileRef.id, fileName: file.originalname, storagePath: filename }
    });

    // Notify other group members
    try {
      for (const memberId of groupData.members) {
        if (memberId === req.user.uid) continue;
        await createNotification({
          userId: memberId,
          type: 'file_uploaded',
          groupId,
          message: `New file uploaded: ${file.originalname}`,
          actorId: req.user.uid
        });
      }
    } catch (notifyErr) {
      console.warn('[Files][Upload] Notification broadcast failed:', notifyErr.message);
    }

    return res.status(201).json({
      success: true,
      message: 'File uploaded successfully',
      file: { id: fileRef.id, ...fileData, uploadedAt: new Date().toISOString(), temporaryUrl: signedUrl }
    });

  } catch (error) {
    console.error('[Files][Upload] Unexpected error:', error);
    return res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// ============================================
// GET FILES BY GROUP
// ============================================
router.get('/group/:groupId', authenticateToken, async (req, res) => {
  console.log('GET /api/files/group/:groupId called for uid:', req.user && req.user.uid, 'groupId:', req.params && req.params.groupId);
  try {
    const { groupId } = req.params;
    const includeSigned = req.query && req.query.signed === '1';

    // Verify user is member of group
    const groupDoc = await db.collection(GROUPS_COLLECTION).doc(groupId).get();
    if (!groupDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'Group not found' 
      });
    }

    const groupData = groupDoc.data();
    console.log('Group data for', groupId, ':', JSON.stringify(groupData));
    if (!Array.isArray(groupData.members)) {
      console.error('Group members missing or invalid for group:', groupDoc.id, 'members:', groupData.members);
      return res.status(500).json({ success: false, error: 'Group members missing or invalid' });
    }

    if (!groupData.members.includes(req.user.uid)) {
      return res.status(403).json({ 
        success: false,
        error: 'Access denied' 
      });
    }

    // Fetch unordered to avoid Firestore composite index requirements; sort in-memory
    const filesSnapshot = await db.collection(FILES_COLLECTION)
      .where('groupId', '==', groupId)
      .get();

    const files = [];
    for (const doc of filesSnapshot.docs) {
      const data = doc.data();
      let tempSigned = null;
      if (includeSigned && data.storagePath) {
        try {
          const [url] = await bucket.file(data.storagePath).getSignedUrl({ action: 'read', expires: Date.now() + 3600 * 1000 });
          tempSigned = url;
        } catch (e) {
          console.warn('[Files][List] Signed URL failed for', data.storagePath, e.message);
        }
      }
      files.push({ id: doc.id, ...data, temporaryUrl: tempSigned });
    }

    // Sort in-memory by uploadedAt (newest first). Handle missing uploadedAt gracefully.
    files.sort((a, b) => {
      const ta = a.uploadedAt && a.uploadedAt._seconds ? a.uploadedAt._seconds * 1000 + (a.uploadedAt._nanoseconds || 0)/1000000 : 0;
      const tb = b.uploadedAt && b.uploadedAt._seconds ? b.uploadedAt._seconds * 1000 + (b.uploadedAt._nanoseconds || 0)/1000000 : 0;
      return tb - ta; // newest first
    });

    res.status(200).json({
      success: true,
      count: files.length,
      files
    });

  } catch (error) {
    console.error('Get files error:', error, error && error.stack);
    const devMsg = (process.env.NODE_ENV !== 'production') ? (error && error.message) : undefined;
    // Return empty files list to avoid UI crash; include debugError for troubleshooting
    return res.status(200).json({
      success: true,
      count: 0,
      files: [],
      debugError: devMsg
    });
  }
});

// ============================================
// DELETE FILE
// ============================================
router.delete('/:fileId', authenticateToken, async (req, res) => {
  try {
    const { fileId } = req.params;
    const fileDoc = await db.collection(FILES_COLLECTION).doc(fileId).get();

    if (!fileDoc.exists) {
      return res.status(404).json({ 
        success: false,
        error: 'File not found' 
      });
    }

    const fileData = fileDoc.data();

    // Only uploader can delete file
    if (fileData.uploadedBy !== req.user.uid) {
      return res.status(403).json({ 
        success: false,
        error: 'Only file uploader can delete file' 
      });
    }

    // Determine storage path
    const filename = fileData.storagePath || (() => {
      if (fileData.fileUrl) {
        const urlParts = fileData.fileUrl.split('/');
        return decodeURIComponent(urlParts.slice(4).join('/'));
      }
      return null;
    })();
    if (!filename) {
      return res.status(400).json({ success: false, error: 'File storage path missing' });
    }

    // Delete from Storage
    await bucket.file(filename).delete();

    // Delete from Firestore
    await db.collection(FILES_COLLECTION).doc(fileId).delete();

    res.status(200).json({
      success: true,
      message: 'File deleted successfully'
    });

  } catch (error) {
    console.error('Delete file error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

module.exports = router;
// Storage health endpoint
router.get('/storage-health', authenticateToken, async (req, res) => {
  try {
    const bucket = admin.storage().bucket();
    const [exists] = await bucket.exists();
    return res.status(200).json({
      success: true,
      bucket: bucket.name,
      exists
    });
  } catch (e) {
    return res.status(500).json({ success: false, error: e.message });
  }
});