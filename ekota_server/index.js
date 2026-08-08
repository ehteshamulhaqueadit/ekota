require('dotenv').config();

const { createApp } = require('./src/app');

const app = createApp();
const port = process.env.PORT || 5000;

app.listen(port, () => {
  console.log(`Ekota backend running on port ${port}`);
});