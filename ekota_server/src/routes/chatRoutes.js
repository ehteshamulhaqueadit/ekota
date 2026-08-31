const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');
const { authenticate } = require('../middleware/auth');

router.use(authenticate);

// Syndicate Threads & Chat History
router.get('/threads', chatController.getSyndicateThreads);
router.get('/history/:listingId', chatController.getChatHistory);
router.post('/upload', chatController.uploadChatMedia);

module.exports = router;
