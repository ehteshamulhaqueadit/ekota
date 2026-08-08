const { createApp } = require('./src/app');

async function testLiveApi() {
  const app = createApp();
  const server = app.listen(5005, async () => {
    console.log('Test server listening on port 5005...');
    try {
      const res = await fetch('http://localhost:5005/api/withdrawals/admin/all');
      const data = await res.json();
      console.log('FETCH SUCCESS! Number of live requests returned:', data.requests?.length);

      // Test processing a request
      const reqId = data.requests[0].id;
      const patchRes = await fetch(`http://localhost:5005/api/withdrawals/admin/${reqId}/process`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'APPROVED', adminNote: 'Verified harvest payout' }),
      });
      const patchData = await patchRes.json();
      console.log('PATCH SUCCESS! Status updated:', patchData.message);
    } catch (err) {
      console.error('API Error:', err.message);
    } finally {
      server.close();
    }
  });
}

testLiveApi();
