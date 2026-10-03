// import postgresPackage from 'pg';
// import dotenv from 'dotenv';

// dotenv.config();

// const { Pool } = postgresPackage;

// const pool = new Pool({
//   connectionString: process.env.DATABASE_URL,
// });

// /**
//  * Runs fn(client) inside a transaction. Commits on success, rolls back on any error.
//  * Pass { userId } so the audit trigger records who performed the action.
//  */
// export async function withTransaction(fn, { userId } = {}) {
//   const client = await pool.connect();
//   try {
//     await client.query('BEGIN');
//     if (userId) {
//       // third argument true = local to this transaction only
//       await client.query("SELECT set_config('app.user_id', $1, true)", [userId]);
//     }
//     const result = await fn(client);
//     await client.query('COMMIT');
//     return result;
//   } catch (err) {
//     try { await client.query('ROLLBACK'); } catch { /* connection already broken */ }
//     throw err;
//   } finally {
//     client.release();
//   }
// }

// export default pool;




import postgresPackage from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const { Pool } = postgresPackage;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

/**
 * Runs fn(client) inside a transaction.
 * - Commits if fn returns normally (even if it returns a "failure" result object).
 * - Rolls back if fn throws.
 * Pass { userId } so DB triggers (order audit) know who is acting.
 */
export async function withTransaction(fn, { userId } = {}) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (userId) {
      // third argument true = local to this transaction only
      await client.query("SELECT set_config('app.user_id', $1, true)", [userId]);
    }
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch {
      /* connection already broken */
    }
    throw err;
  } finally {
    client.release();
  }
}

export default pool;