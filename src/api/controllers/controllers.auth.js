import pool from '../../config/db/index.js';
import { AuthModel } from '../models/models.auth.js';
import {
  generateOTP,
  hashData,
  hashPassword,
  comparePassword,
  generateJWT
} from '../../lib/utils/utils.auth.js';



//  REGISTER
export const register = async (req, res, next) => {
  const client = await pool.connect();
  try {
    const { full_name, email, password, phone, role } = req.body;

    if (!full_name || !email || !password || !phone ) {
      return res.status(400).json({ status: 'fail', message: 'Full name, email, and password are required.' });
    }

    await client.query('BEGIN');

    // Check if user already exists with this email OR phone
    const existingUser = await AuthModel.findUserByEmailOrPhone(email, phone, client);
    if (existingUser) {
      await client.query('ROLLBACK');

      let message = 'An account with these details already exists.';
      if (existingUser.email === email.toLowerCase()) {
        message = 'An account with this email address already exists.';
      }
       else if (phone && existingUser.phone === phone) {
        message = 'An account with this phone number already exists.';
      }

      return res.status(409).json({ status: 'fail', message });
    }

    const password_hash = await hashPassword(password);
    
    // Pass strictly phone
    const user = await AuthModel.createUser(
      { full_name, email, password_hash, phone, role }, 
      client
    );

    const rawOtp = generateOTP();
    const otpHash = hashData(rawOtp);
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

    await AuthModel.createOTP(user.id, otpHash, 'EMAIL_VERIFICATION', expiresAt, client);

    await client.query('COMMIT');

    console.log(`[DEV ONLY] Verification OTP for ${user.email}: ${rawOtp}`);

    return res.status(201).json({
      status: 'success',
      message: 'User registered successfully. Verification OTP sent to email. OTP is valid for 15 minutes.',
      data: { user }
    });
  } catch (error) {
    await client.query('ROLLBACK');
    next(error);
  } finally {
    client.release();
  }
};
