const express = require('express');
const { authenticate } = require('../middleware/auth');
const {
  storeInWarehouse,
  retrieveFromWarehouse,
  getWarehouseFee,
  getMyWarehouseItems
} = require('../controllers/warehouseController');

const router = express.Router();

router.post('/warehouse/store', authenticate, storeInWarehouse);
router.post('/warehouse/retrieve', authenticate, retrieveFromWarehouse);
router.get('/warehouse/fees/:listingId', authenticate, getWarehouseFee);
router.get('/warehouse/my', authenticate, getMyWarehouseItems);

module.exports = router;
