const prisma = require('../config/prisma');

/**
 * Fetch notifications for authenticated user
 */
async function getUserNotifications(req, res, next) {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.json({ notifications: [], unreadCount: 0 });
    }

    const notifications = await prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    const unreadCount = await prisma.notification.count({
      where: { userId, isRead: false },
    });

    return res.json({ notifications, unreadCount });
  } catch (error) {
    return next(error);
  }
}

/**
 * Mark a single notification as read
 */
async function markAsRead(req, res, next) {
  try {
    const userId = req.user?.id;
    const { id } = req.params;

    const notification = await prisma.notification.findFirst({
      where: { id, userId },
    });

    if (!notification) {
      return res.status(404).json({ message: 'Notification not found' });
    }

    const updated = await prisma.notification.update({
      where: { id },
      data: { isRead: true },
    });

    return res.json({ message: 'Notification marked as read', notification: updated });
  } catch (error) {
    return next(error);
  }
}

/**
 * Mark all notifications for user as read
 */
async function markAllAsRead(req, res, next) {
  try {
    const userId = req.user?.id;
    if (!userId) return res.json({ message: 'All notifications marked as read' });

    await prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });

    return res.json({ message: 'All notifications marked as read' });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  getUserNotifications,
  markAsRead,
  markAllAsRead,
};
