require('dotenv').config();
const express = require('express');
const cors = require('cors');

// Import routes
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/user');
const groupRoutes = require('./routes/groups');
const taskRoutes = require('./routes/tasks');
const fileRoutes = require('./routes/files');
const notificationRoutes = require('./routes/notifications');
const activityRoutes = require('./routes/activities');
const dashboardRoutes = require('./routes/dashboard');

const app = express();

// Initialize Firebase
require('./config/firebase');

// ===== MIDDLEWARE (ORDER MATTERS!) =====
// 1. Body parsers FIRST
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Enable CORS for web development
app.use(cors({
  origin: '*', // Allow all origins during development
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// 3. Request logging (optional, helpful for debugging)
app.use((req, res, next) => {
  console.log(`${req.method} ${req.path}`);
  next();
});

// ===== ROUTES =====
app.use('/api/auth', authRoutes);
app.use('/api/user', userRoutes);
app.use('/api/groups', groupRoutes);
app.use('/api/tasks', taskRoutes);
app.use('/api/files', fileRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/activities', activityRoutes);
app.use('/api/dashboard', dashboardRoutes);

// Health Check
app.get('/health', (req, res) => {
  res.status(200).json({ 
    success: true,
    message: 'Groupify API with Firebase is running',
    timestamp: new Date().toISOString(),
    endpoints: {
      auth: '/api/auth',
      user: '/api/user',
      groups: '/api/groups',
      tasks: '/api/tasks',
      files: '/api/files',
      notifications: '/api/notifications',
      activities: '/api/activities',
      dashboard: '/api/dashboard'
    }
  });
});

// 404 Handler
app.use((req, res) => {
  res.status(404).json({ 
    success: false,
    error: 'Route not found' 
  });
});

// Error Handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ 
    success: false,
    error: 'Something went wrong!' 
  });
});

// Start Server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Groupify Server running on port ${PORT}`);
  console.log(`📍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔥 Firebase Project: ${process.env.FIREBASE_PROJECT_ID}`);
  console.log(`\n📋 Available Endpoints:`);
  console.log(`   - Authentication: /api/auth`);
  console.log(`   - User Profile: /api/user`);
  console.log(`   - Groups: /api/groups`);
  console.log(`   - Tasks: /api/tasks`);
  console.log(`   - Files: /api/files`);
  console.log(`   - Notifications: /api/notifications`);
  console.log(`   - Activities: /api/activities`);
  console.log(`   - Dashboard: /api/dashboard`);
});