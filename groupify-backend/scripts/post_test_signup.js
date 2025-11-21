const http = require('http');

const data = JSON.stringify({
  uid: process.argv[2] || 'TEST_UID_123',
  fullName: process.argv[3] || 'Test Signup',
  email: process.argv[4] || 'testsignup@example.com',
  school: 'Test School',
  course: 'Test Course',
  yearLevel: '1st Year',
  section: 'A'
});

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/api/auth/test-signup',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(data)
  }
};

const req = http.request(options, (res) => {
  console.log('Status:', res.statusCode);
  let body = '';
  res.on('data', (chunk) => body += chunk);
  res.on('end', () => {
    console.log('Body:', body);
    process.exit(0);
  });
});

req.on('error', (e) => {
  console.error('Request error:', e.message);
  process.exit(2);
});

req.write(data);
req.end();
