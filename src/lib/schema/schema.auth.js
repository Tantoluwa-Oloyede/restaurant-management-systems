import { z } from "zod";

const full_name = z
  .string({ required_error: "Full name is required" })
  .trim()
  .min(2, "Name must be at least 2 characters")
  .max(100, "Name must be 100 characters or fewer");

const email = z
  .string({ required_error: "Email is required" })
  .trim()
  .toLowerCase()
  .email("Enter a valid email address")
  .max(150, "Email must be 150 characters or fewer");

const phone = z
  .string()
  .trim()
  .regex(
    /^\+?[0-9]{7,15}$/,
    "Phone number must be 7-15 digits, optionally starting with +",
  );

// Strict password policy for account creation & resets
const password = z
  .string({ required_error: "Password is required" })
  .min(8, "Password must be at least 8 characters")
  .refine(
    (v) => Buffer.byteLength(v, "utf8") <= 72,
    "Password is too long (max 72 bytes)",
  )
  .regex(/[A-Za-z]/, "Password must contain at least one letter")
  .regex(/[0-9]/, "Password must contain at least one number");

// Flexible password check for authentication/verification steps
const anyPassword = (label) =>
  z
    .string({ required_error: `${label} is required` })
    .min(1, `${label} is required`)
    .max(128, `${label} is too long`);

const otp = z
  .string({ required_error: "OTP is required" })
  .trim()
  .regex(/^\d{6}$/, "OTP code must be exactly 6 digits");

const purpose = z.enum(["EMAIL_VERIFICATION", "PASSWORD_RESET"], {
  errorMap: () => ({
    message: "Purpose must be 'EMAIL_VERIFICATION' or 'PASSWORD_RESET'",
  }),
});

// Matches PostgreSQL user_role ENUM
const role = z.enum(["ADMIN", "WAITER", "KITCHEN_STAFF", "MANAGER"], {
  errorMap: () => ({ message: "Invalid user role specified" }),
});

// POST /api/v1/auth/register
export const registerSchema = z.object({
  full_name,
  email,
  password,
  phone,
  role: role.optional(),
});

// POST /api/v1/auth/verify-email
export const verifyEmailSchema = z.object({
  email,
  otp,
});

// POST /api/v1/auth/resend-otp
export const resendOtpSchema = z.object({
  email,
  purpose,
});

// POST /api/v1/auth/login
export const loginSchema = z.object({
  email,
  password: anyPassword("Password"),
});

// POST /api/v1/auth/forgot-password
export const forgotPasswordSchema = z.object({
  email,
});

// POST /api/v1/auth/reset-password
export const resetPasswordSchema = z.object({
  email,
  otp,
  new_password: password,
});

// PATCH /api/v1/users/me (Profile updates)
export const updateMeSchema = z
  .object({
    full_name: full_name.optional(),
    phone: phone.nullable().optional(), // Allows null to clear saved contact info
  })
  .refine((d) => d.full_name !== undefined || d.phone !== undefined, {
    message: "Provide at least one field to update (full_name or phone)",
  });

// PATCH /api/v1/auth/change-password
export const changePasswordSchema = z
  .object({
    current_password: anyPassword("Current password"),
    new_password: password,
  })
  .refine((d) => d.current_password !== d.new_password, {
    message: "New password must be different from current password",
    path: ["new_password"],
  });
