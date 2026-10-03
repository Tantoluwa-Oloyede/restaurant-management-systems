import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';

const SALT_ROUNDS = 12;

export const generateOTP = () => {
  return Math.floor(100000 + Math.random() * 900000).toString(); // 6-digit numeric string
};

export const hashData = (data) => {
  return crypto.createHash('sha256').update(data).digest('hex');
};

export const hashPassword = async (password) => {
  return await bcrypt.hash(password, SALT_ROUNDS);
};

export const comparePassword = async (password, hash) => {
  return await bcrypt.compare(password, hash);
};

export const generateJWT = (user) => {
  return jwt.sign(
    { id: user.id, role: user.role, email: user.email },
    process.env.JWT_SECRET || 'super_secret_jwt_key',
    { expiresIn: process.env.JWT_EXPIRES_IN || '8h' }
  );
};

export const verifyJWT = (token) => {
  return jwt.verify(token, process.env.JWT_SECRET || 'super_secret_jwt_key');
};