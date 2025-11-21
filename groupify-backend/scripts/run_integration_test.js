const http = require('http');

function post(path, payload, cb) {
  const data = JSON.stringify(payload);
  const options = {
    hostname: 'localhost',
    port: 3000,
    path,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(data)
    }
  };

  const req = http.request(options, (res) => {
    let body = '';
    res.on('data', (c) => body += c);
    res.on('end', () => cb(null, res.statusCode, body));
  });

  req.on('error', (e) => cb(e));
  req.write(data);
  req.end();
}

async function main() {
  const uid = process.argv[2] || 'TEST_UID_123';
  console.log('Integration test using uid:', uid);

  // 1) call test-signup
  post('/api/auth/test-signup', { uid, fullName: 'IT User', email: 'it@example.com' }, (err, status, body) => {
    if (err) return console.error('test-signup error:', err);
    console.log('test-signup status:', status);
    console.log('test-signup body:', body);

    // 2) call dev-verify
    post('/api/auth/dev-verify', { uid }, (err2, status2, body2) => {
      if (err2) return console.error('dev-verify error:', err2);
      console.log('dev-verify status:', status2);
      console.log('dev-verify body:', body2);
    });
  });
}

main();
