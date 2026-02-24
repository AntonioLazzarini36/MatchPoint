### MatchPoint is a date-based app for sports. Here you can find your perfect partner for your tennis match or running session.

## How to init everything:
- DB:
    - docker compose up -d db

- Backend:
    - cd services/api
    - npm run start:dev

- Flutter / Frontend:
    - cd apps/mobile
    - flutter run -d chrome

## Additional information:
- apps/mobile/ → Flutter:
This is the frontend. Just the interface. It does not own a database. Calls the backend via HTTP.

- services/api/ → Backend (NestJS + TypeScript):
Backend server built with NestJS. Uses Prisma as ORM. Connects to PostgreSQL. Listens at localhost:3000.

- Prisma:
ORM (layer between code and database). Defines the models. Generates the client for the backend. Executes migrations.

- PostgreSQL:
Database. Runs inside Docker. Lives at localhost:5432.

- Docker:
Currently only runs the database. Flutter and backend are not yet dockerized.

## Regarding the API POST and GET endpoints:
Base / misc
GET /
GET /health

Add JWT authentication with access/refresh tokens
POST /auth/register
POST /auth/login
POST /auth/refresh
POST /auth/logout

Add authenticated "me" endpoints (profile + preferences)
GET /me
PATCH /me/profile
PATCH /me/preferences

Add discover feed endpoint
GET /discover?sport=TENNIS|RUNNING

Implement swipe + match core flow
POST /swipes { toUserId, sport, type: LIKE|PASS }
Creates/updates swipe, returns { match: true, matchId } on mutual LIKE

Matches
GET /matches
Lists matches for current user with other user profile info

Chats
GET /chats/:matchId/messages
POST /chats/:matchId/messages
PATCH /chats/:matchId/read

Users / Profiles
GET /users/:userId/profile
Returns the public profile data for a given userId (requires auth)

- Prisma schema/migrations updated for SwipeType, Swipe, Match + seed tooling
