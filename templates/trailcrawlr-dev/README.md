# TrailCrawlr Dev Environment

Kubernetes development workspace for the TrailCrawlr fullstack web application.

## Services

| Service   | Image                    | Port |
|-----------|--------------------------|------|
| Dev       | codercom/enterprise-node | —    |
| PostGIS   | postgis/postgis:16-3.4   | 5432 |
| Redis     | redis:7-alpine           | 6379 |

## Included Tools

- **code-server** — VS Code in the browser
- **mux** — terminal multiplexer
- **Cursor** — AI-powered desktop IDE
- **pnpm** — fast Node.js package manager (installed via corepack)

## Forwarded Ports

| App      | URL                    | Default Port |
|----------|------------------------|--------------|
| Frontend | http://localhost:5173  | 5173 (Vite)  |
| API      | http://localhost:3001  | 3001 (Express)|

## Startup Behaviour

On workspace start the agent will:

1. Install common development packages (git, curl, ripgrep, etc.)
2. Install pnpm via corepack
3. Clone the TrailCrawlr repository
4. Wait for PostGIS and Redis sidecars to become healthy
5. Create the PostGIS extension in the `trailcrawlr` database
6. Generate a `.env` file (if one does not already exist)
7. Run `pnpm install` (if `package.json` is present)
