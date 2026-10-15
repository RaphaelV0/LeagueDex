# Firestore security validation

These are development tools only. They add no dependency to the native iOS app.
Use Node.js 22+, npm and Java 21+:

```sh
npm ci
npm run test:rules
```

The command starts the Firestore emulator with the repository's rules and the
`demo-leaguedex` project ID. Tests refuse to start without an emulator address;
they never contact the app's live Firebase project. CI runs the same command.
No Firebase login, service-account credentials or production data are needed.

The suite verifies unauthenticated and cross-user denial (including admin access
to private accounts), collection and document reads, unknown paths, exact field
shapes, item array bounds/types, server timestamps, optimistic build revisions,
deletion tombstones, immutable quiz history/daily participation and catalog roles.

`users/{uid}` is a namespace; the app currently creates no parent profile document.
Only `favorites`, `builds`, `comparisons` and `quizRuns` have private client access.
Favorites use `selected: false`; builds use `deleted: true` plus an increased
revision and a distinct `mutationID`, retaining conflict and migration history.
The mutation identifier lets a device recognize an acknowledged transaction after
an interrupted local save without submitting the operation twice. Private admin access is denied.
Catalog writes require a trusted `admin: true` custom claim provisioned by an
administrator outside the app. New collections default to denied access.

Quiz arithmetic is validated, but answers are produced on the device. Scores are
personal history, not a trusted competitive ranking or a basis for valuable rewards.

Phase A leaves `venues` readable by signed-in users, with client writes restricted
to trusted administrators. The authenticated community submission/moderation schema
is added in Phase D before reopening user contribution creation.

This repository does not deploy automatically. Review existing live schemas and
rules, enable the selected Authentication provider, run these tests, then deploy
reviewed rules explicitly against the intended project. Existing production rules
must never be replaced with `allow write: if true` to bypass permission failures.
