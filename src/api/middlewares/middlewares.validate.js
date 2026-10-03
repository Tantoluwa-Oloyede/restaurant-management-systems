// src/api/middlewares/validate.js
export const validate = (schema) => async (req, res, next) => {
  try {
    // Parse and sanitize req.body against Zod schema
    req.body = await schema.parseAsync(req.body);
    next();
  } catch (error) {
    if (error.name === 'ZodError') {
      return res.status(400).json({
        status: 'fail',
        message: 'Validation failed',
        errors: error.errors.map((err) => ({
          field: err.path.join('.'),
          message: err.message
        }))
      });
    }
    next(error);
  }
};