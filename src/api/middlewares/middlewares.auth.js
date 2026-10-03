import { verifyJWT } from '../../lib/utils/utils.auth.js';

export const authenticate = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ status: 'fail', message: 'Authentication token required.' });
    }

    const token = authHeader.split(' ')[1];
    const decoded = verifyJWT(token);
    req.user = decoded; // Attach user payload ({ id, role, email }) to request
    next();
  } catch (error) {
    return res.status(401).json({ status: 'fail', message: 'Invalid or expired token.' });
  }
};

export const authorize = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ status: 'fail', message: 'Forbidden: Insufficient rights.' });
    }
    next();
  };
};