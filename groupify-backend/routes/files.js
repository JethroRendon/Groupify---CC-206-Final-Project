// routes/files.js
const express = require('express');
const multer = require('multer');
const { db, admin } = require('../config/firebase');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();
const FILES_COLLECTION = 'files';
const GROUPS_COLLECTION = 'groups';

// Initialize Firebase Storage bucket
const bucket = admin.storage().bucket();

// Configure multer for memory storage
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
});

// ============================================
// UPLOAD FILE
// ============================================
router.post('/upload', authenticateToken, upload.single('file'), async (req, res) => {
  try {
    const { groupId, description } = req.body;
    const file = req.file;

    if (!file) {
      return res.status(400).json({ 
        success: false,
        error: 'No file uploaded' 
      });
    }

    if (!groupId) {
      return res.status(400).json({ 
        success: false,
        error: 'Group ID is required' 
      });
    }

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

    // Create unique filename
    const timestamp = Date.now();
    const filename = `groups/${groupId}/files/${timestamp}_${file.originalname}`;

    // Upload to Firebase Storage
    const fileUpload = bucket.file(filename);
    const blobStream = fileUpload.createWriteStream({
      metadata: {
        contentType: file.mimetype,
      },
    });

    blobStream.on('error', (error) => {
      console.error('Upload error:', error);
      res.status(500).json({ 
        success: false,
        error: 'File upload failed' 
      });
    });

    blobStream.on('finish', async () => {
      // Make file publicly accessible
      await fileUpload.makePublic();

      // Get public URL
      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filename}`;

      // Save file metadata to Firestore
      const fileData = {
        fileName: file.originalname,
        fileUrl: publicUrl,
        fileType: file.mimetype,
        fileSize: file.size,
        uploadedBy: req.user.uid,
        groupId,
        description: description || '',
        uploadedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      const fileRef = await db.collection(FILES_COLLECTION).add(fileData);

      res.status(201).json({
        success: true,
        message: 'File uploaded successfully',
        file: {
          id: fileRef.id,
          ...fileData,
          uploadedAt: new Date().toISOString()
        }
      });
    });

    blobStream.end(file.buffer);

  } catch (error) {
    console.error('Upload file error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
    });
  }
});

// ============================================
// GET FILES BY GROUP
// ============================================
router.get('/group/:groupId', authenticateToken, async (req, res) => {
  try {
    const { groupId } = req.params;

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

    const filesSnapshot = await db.collection(FILES_COLLECTION)
      .where('groupId', '==', groupId)
      .orderBy('uploadedAt', 'desc')
      .get();

    const files = [];
    filesSnapshot.forEach(doc => {
      files.push({
        id: doc.id,
        ...doc.data()
      });
    });

    res.status(200).json({
      success: true,
      count: files.length,
      files
    });

  } catch (error) {
    console.error('Get files error:', error);
    res.status(500).json({ 
      success: false,
      error: 'Internal server error' 
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

    // Extract filename from URL
    const urlParts = fileData.fileUrl.split('/');
    const filename = decodeURIComponent(urlParts.slice(4).join('/'));

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