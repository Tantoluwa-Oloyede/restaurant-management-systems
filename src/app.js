import express from 'express';
import dotenv from 'dotenv';
import routes from './api/routes/index.js';

dotenv.config();

const app = express();
app.disable('x-powered-by');


app.use(express.json());
app.use(express.urlencoded({ extended: true }));

routes(app); // must come BEFORE the 404 handler

app.get('/', (_req, res) => {
  res.status(200).json({ message: 'Restaurant Management System Active' });
});

// 404 for anything that didn't match a route
app.use((_req, res) => {
  res.status(404).json({ error: 'Resource not found' });
});

// Global safety net: must be LAST and must have all 4 parameters
app.use((err, _req, res, _next) => {
  // Malformed JSON sent by the client is their mistake, not a server bug
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'Invalid JSON in request body' });
  }

  console.error(err.stack);
  res.status(500).json({
    status: 'error',
    message: 'Ooooops! Something broke somewhere',
  });
});

const port = process.env.PORT || 4000;
const host = process.env.HOST || '0.0.0.0';

app.listen(port, host, () => {
  console.log(`Server running on http://${host}:${port}`);
});