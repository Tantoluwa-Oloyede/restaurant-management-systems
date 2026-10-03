export const AUTH_QUERIES = {
  // Users
  FIND_USER_BY_EMAIL: `
    SELECT id, full_name, email, password_hash, role, is_active, is_verified 
    FROM users WHERE email = $1
  `,
  FIND_USER_BY_EMAIL_OR_PHONE: `
        SELECT id, email, phone 
        FROM users 
        WHERE email = $1 OR (phone = $2 AND phone IS NOT NULL)
  `,
  FIND_USER_BY_ID: `
    SELECT id, full_name, email, phone, role, is_active, is_verified, created_at, updated_at 
    FROM users WHERE id = $1
  `,
  CREATE_USER: `
    INSERT INTO users (full_name, email, password_hash, phone, role, is_verified)
    VALUES ($1, $2, $3, $4, COALESCE($5, 'WAITER'::user_role), false)
    RETURNING id, full_name, email, role, is_verified, created_at
  `,
  UPDATE_USER_VERIFIED: `
    UPDATE users SET is_verified = true WHERE id = $1
  `,
  UPDATE_USER_PASSWORD: `
    UPDATE users SET password_hash = $1 WHERE id = $2
  `,

  // OTPs
  CREATE_OTP: `
    INSERT INTO otps (user_id, otp_hash, purpose, expires_at)
    VALUES ($1, $2, $3, $4)
  `,
  FIND_VALID_OTP: `
    SELECT id FROM otps 
    WHERE user_id = $1 AND otp_hash = $2 AND purpose = $3 
      AND is_used = false AND expires_at > NOW()
  `,
  INVALIDATE_EXISTING_OTPS: `
    UPDATE otps SET is_used = true 
    WHERE user_id = $1 AND purpose = $2 AND is_used = false
  `,
  MARK_OTP_USED: `
    UPDATE otps SET is_used = true WHERE id = $1
  `,

  // Staff Shifts
  FIND_ACTIVE_SHIFT: `
    SELECT id, clock_in, shift_status 
    FROM staff_shifts 
    WHERE staff_id = $1 AND shift_status = 'ACTIVE'
  `,
  CREATE_CLOCK_IN: `
    INSERT INTO staff_shifts (staff_id, clock_in, shift_status)
    VALUES ($1, NOW(), 'ACTIVE')
    RETURNING id, staff_id, clock_in, shift_status
  `,
  UPDATE_CLOCK_OUT: `
    UPDATE staff_shifts 
    SET clock_out = NOW(), shift_status = 'ENDED' 
    WHERE id = $1 
    RETURNING id, staff_id, clock_in, clock_out, shift_status
  `
};