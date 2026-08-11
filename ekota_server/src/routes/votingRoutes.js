const express = require('express');
const { authenticate } = require('../middleware/auth');
const {
  createProposal,
  getProposals,
  castVote,
  getVotingResults
} = require('../controllers/votingController');

const router = express.Router();

router.post('/rental-pool/:poolItemId/proposals', authenticate, createProposal);
router.get('/rental-pool/:poolItemId/proposals', authenticate, getProposals);
router.post('/proposals/:proposalId/vote', authenticate, castVote);
router.get('/proposals/:proposalId/results', authenticate, getVotingResults);

module.exports = router;
