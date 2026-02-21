Still on development

I am trying to create an app with different services and orchestrated by docker.

API: authentication + profiles + discovery/matching + image storage

DB: Postgres

Auth: Probably use a provider like: Firebase Auth / Supabase Auth / Auth0.

Notifications (further on): worker + cqueue (BullMQ/Redis) o services

Frontend: Inside apps/mobile/ -> Run using flutter run -d chrome