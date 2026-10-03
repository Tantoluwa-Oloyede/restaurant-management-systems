import pool from '../../config/db/index.js';
import { AUTH_QUERIES } from '../queries/queries.auth.js';

export const AuthModel = {
  // Database Connection Runner (Supports DB Transactions when a client is passed)
  async query(text, params, client = null) {
    const executor = client || pool;
    return await executor.query(text, params);
  },

  async findUserByEmail(email, client = null) {
    const res = await this.query(AUTH_QUERIES.FIND_USER_BY_EMAIL, [email.toLowerCase()], client);
    return res.rows[0];
  },

  async findUserById(id, client = null) {
    const res = await this.query(AUTH_QUERIES.FIND_USER_BY_ID, [id], client);
    return res.rows[0];
  },

  async createUser(userData, client = null) {
    const { full_name, email, password_hash, phone, role } = userData;
    const res = await this.query(
      AUTH_QUERIES.CREATE_USER,
      [full_name, email.toLowerCase(), password_hash, phone || null, role],
      client
    );
    return res.rows[0];
  },

    async findUserByEmailOrPhone(email, phone, client = null) {
    const res = await this.query(
        AUTH_QUERIES.FIND_USER_BY_EMAIL_OR_PHONE,
        [email.toLowerCase(), phone || null],
        client
    );
    return res.rows[0];
    },

  async setUserVerified(userId, client = null) {
    await this.query(AUTH_QUERIES.UPDATE_USER_VERIFIED, [userId], client);
  },

  async setUserPassword(userId, passwordHash, client = null) {
    await this.query(AUTH_QUERIES.UPDATE_USER_PASSWORD, [passwordHash, userId], client);
  },

  async createOTP(userId, otpHash, purpose, expiresAt, client = null) {
    await this.query(AUTH_QUERIES.CREATE_OTP, [userId, otpHash, purpose, expiresAt], client);
  },

  async findValidOTP(userId, otpHash, purpose, client = null) {
    const res = await this.query(AUTH_QUERIES.FIND_VALID_OTP, [userId, otpHash, purpose], client);
    return res.rows[0];
  },

  async invalidatePreviousOTPs(userId, purpose, client = null) {
    await this.query(AUTH_QUERIES.INVALIDATE_EXISTING_OTPS, [userId, purpose], client);
  },

  async markOTPUsed(otpId, client = null) {
    await this.query(AUTH_QUERIES.MARK_OTP_USED, [otpId], client);
  },

  async getActiveShift(staffId, client = null) {
    const res = await this.query(AUTH_QUERIES.FIND_ACTIVE_SHIFT, [staffId], client);
    return res.rows[0];
  },

  async createClockIn(staffId, client = null) {
    const res = await this.query(AUTH_QUERIES.CREATE_CLOCK_IN, [staffId], client);
    return res.rows[0];
  },

  async updateClockOut(shiftId, client = null) {
    const res = await this.query(AUTH_QUERIES.UPDATE_CLOCK_OUT, [shiftId], client);
    return res.rows[0];
  }
};