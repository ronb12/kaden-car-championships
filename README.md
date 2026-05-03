# Kaden's Racing Championships

Kaden's Racing Championships is a browser and iOS racing game with garage car selection, tournament play, solo racing, online/global features, police mode, controller support, and an iOS app wrapper.

## Live Game

Production: https://kaden-car-championships.vercel.app/

## Main Files

- `index.html` - main racing game
- `garage.html` - garage and car selection page
- `settings.html` - settings and account controls
- `privacy.html` - privacy policy
- `terms.html` - terms of service
- `api/` - Vercel serverless endpoints for global scores, multiplayer presence, matchmaking, and account deletion
- `db/schema.sql` - Neon/Postgres schema
- `garage-cars/` - garage car images
- `ios/` - native iOS project and bundled web game assets

## Features

- Solo quick races and championship tournament flow
- Global play status and online player count support
- Multiplayer presence so players can see other racers online
- Global score and leaderboard endpoints when Neon/Postgres is connected
- 30-car garage plus police interceptor selection
- Police chase mode for city racing
- Automatic/manual transmission with paddle-style shift controls
- Mobile touch controls, keyboard controls, controller support, and steering-wheel-style gamepad input
- Finish screen with race winner, placements, and driver times
- iOS app bundle with app icon, splash background, privacy manifest, settings, terms, and privacy pages

## Local Web Testing

Open `index.html` directly in a browser for offline solo play, or run a local static server if browser security blocks local assets.

```sh
npx serve .
```

## Vercel Deployment

This project is deployed to Vercel as `kaden-car-championships`.

Required environment variables for global features:

- `DATABASE_URL` or `POSTGRES_URL` or `NEON_DATABASE_URL`

Do not commit database URLs or secrets to GitHub. Add them in the Vercel project settings.

## iOS Build

The iOS project is in `ios/KadenRacing.xcodeproj`.

A simulator build can be checked with:

```sh
xcodebuild -project ios/KadenRacing.xcodeproj -scheme KadenRacing -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Notes

The web game and iOS web bundle should stay in sync. When `index.html`, garage pages, policies, or assets change, copy the updated web files into `ios/KadenRacing/WebBundle/` before building the iOS app.
