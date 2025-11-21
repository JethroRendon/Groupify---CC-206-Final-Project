const http = require('http');

http.get('http://localhost:3000/health', (res) => {
  console.log('Health check status:', res.statusCode);
  let body = '';
  res.on('data', (chunk) => body += chunk);
  res.on('end', () => {
    console.log('Body:', body);
    process.exit(0);
  });
}).on('error', (err) => {
  console.error('Health check failed:', err.message);
  process.exit(2);
});
