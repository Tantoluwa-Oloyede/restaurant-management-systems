// import nodemailer from "nodemailer";
// import dotenv from "dotenv";

// dotenv.config();

// const isDevelopment = process.env.NODE_ENV !== "production";

// const transporter = process.env.SMTP_HOST
//   ? nodemailer.createTransport({
//       host: process.env.SMTP_HOST,
//       port: Number(process.env.SMTP_PORT || 587),
//       secure: process.env.SMTP_SECURE === "true",
//       auth: process.env.SMTP_USER
//         ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASSWORD }
//         : undefined,
//     })
//   : null;

// export async function sendOtpEmail({ email, otp, purpose }) {
//   if (isDevelopment || !transporter) {
//     console.log(`[auth] ${purpose} OTP for ${email}: ${otp}`);
//     return;
//   }

//   await transporter.sendMail({
//     from: process.env.SMTP_FROM || process.env.SMTP_USER,
//     to: email,
//     subject:
//       purpose === "EMAIL_VERIFICATION"
//         ? "Verify your email"
//         : "Reset your password",
//     text: `Your OTP is ${otp}. It expires in 10 minutes.`,
//   });
// }

import "dotenv/config";
import nodemailer from "nodemailer";

const smtpConfigured = Boolean(process.env.SMTP_HOST);

const transporter = smtpConfigured
  ? nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 587),
      secure: process.env.SMTP_SECURE === "true", // true for port 465, false for 587
      auth: process.env.SMTP_USER
        ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
        : undefined,
    })
  : null;

/**
 * Sends one email.
 * - With SMTP_HOST set: sends for real.
 * - Without it (development only): prints the email in the terminal so you can copy the OTP.
 * - Without it in production: throws, because printing codes in production logs would be a leak.
 */
export async function sendEmail({ to, subject, text, html }) {
  if (!transporter) {
    if (process.env.NODE_ENV === "production") {
      throw new Error("SMTP is not configured");
    }
    console.log(
      `\n[email:dev] To: ${to}\n[email:dev] Subject: ${subject}\n${text}\n`,
    );
    return;
  }

  await transporter.sendMail({
    from: process.env.EMAIL_FROM || "Restaurant System <no-reply@localhost>",
    to,
    subject,
    text,
    html,
  });
}

export function sendOtpEmail({ email, otp, purpose }) {
  return sendEmail({
    to: email,
    subject:
      purpose === "EMAIL_VERIFICATION"
        ? "Verify your email"
        : "Reset your password",
    text: `Your OTP is ${otp}. It expires in 10 minutes.`,
  });
}
