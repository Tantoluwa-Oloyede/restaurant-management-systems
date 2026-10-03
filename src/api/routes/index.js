import authRoutes from "./routes.auth.js";
// Later: import usersRoutes from './users.routes.js'; and so on

export default function routes(app) {
  app.use("/api/v1/auth", authRoutes);
  // app.use('/api/users', usersRoutes);
}
