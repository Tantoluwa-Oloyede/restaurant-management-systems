import { Router } from 'express';
import { validate } from '../middlewares/middlewares.validate.js';
import {
  registerSchema
} from '../../lib/schema/schema.auth.js';

import {
  register
} from '../controllers/controllers.auth.js';

const router = Router();

router.post('/register', validate(registerSchema), register);


export default router;