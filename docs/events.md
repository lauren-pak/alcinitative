# Events and Huddle (October 2026 redesign)

The app's main purpose is now **in-person social sporting events**: athletes meet online in Huddle, then meet in person at events hosted every couple of weeks. Huddle replaces the problem/solution feed with positive, athlete-led sharing, which lowers the misinformation risk.

Bottom tabs: **Events · Huddle · Profile** ("Me" in Easy mode). Returning members land on Events.

## Huddle

- **Spotlight**: quick clips and posts from athletes' own experience (`PostType.experience`).
- **Ask an athlete**: questions answered with "what worked for me" (`PostType.question`). Questions carry the "not professional advice" banner.
- Four positive categories (`Topic`): **Training wins**, **Mindset**, **Game day**, **Team & life**. Old posts with `injury`, `nutrition` or `competition` are read through `Topic.legacy`, and queries include the old names (`Topic.storedNames`), so nothing needs migrating.

## Events

| Path | Readable by | Written by |
|---|---|---|
| `events/{eventId}` | signed-in members | organisers (create and edit); `goingCount` moves by ±1 with a member's own RSVP |
| `events/{eventId}/rsvps/{uid}` | that member and organisers | that member |
| `organisers/{uid}` | that organiser | the Firebase console only |

- **Adding an organiser:** in the Firebase console, create a doc `organisers/{their uid}` (any fields). They then see a **New event** button on Events, the RSVP list on each event, and **Cancel event**.
- **Capacity and waitlist:** an RSVP takes a spot if there is one, otherwise joins the waitlist, in one transaction with `goingCount` (the rules check the pairing and the capacity). When a spot opens, anyone on the waitlist can take it (first come, first served; there's no automatic promotion without a server function).
- **Safeguarding:**
  - Every event names a **safety lead**.
  - Organisers can mark an event **18+ only**; the rules then refuse under-18 RSVPs.
  - Under-18s RSVP with a **parent or guardian's name, phone and consent**. Adults store no guardian fields (data minimisation).
  - Members only see how many are going, never the attendee list. Organisers see names, support people and guardian contacts.
  - Members can say they're bringing a **support person** (carer, coach or family), which doesn't take a spot.
- **Deleting an account:** `cancelAllMyRsvps` frees upcoming spots first, then `deleteContributions` deletes the RSVP records. Past RSVPs can be deleted without changing the count.
- Events are cancelled (`cancelled: true`), never deleted, so people who RSVPed can see what happened.

## Build plan

1. ✅ Layout: Events · Huddle · Profile, Spotlight and Ask an athlete, the four categories.
2. ✅ Events, first version: organisers create events, members RSVP (capacity, waitlist, support person, guardian consent), organiser RSVP list, cancel.
3. ✅ **Athlete verification:** athletes ask in Settings → Get verified (`verificationRequests/{uid}`); moderators or organisers approve on Profile → Verify athletes (`verifiedAthletes/{uid}`). Verified athletes get a ✓ (`authorVerified` on posts and replies, which the rules check is true exactly when the writer is verified). Only they share spotlights (`type == 'experience'`) and answer questions (replies on a question; the asker can also reply).
4. ✅ **Weekly Huddle question:** moderators set it from the banner at the top of Spotlight (`prompts/{id}`; the newest is current). Verified athletes "Answer it" with a spotlight carrying `promptId`/`promptText`; "See answers" lists them. **Every "Ask an athlete" question is held for a moderator** (`HoldReason.newQuestion`, enforced by the rules) before it appears.
5. ✅ **Weekly streaks and badges** (`lib/models/streaks.dart`): a week counts if the member posts or goes to an event (Monday–Sunday). Shown on the profile: streak card with progress to the next milestone (1, 2, 4, 8, 12 weeks) and a row of badges (streaks, first spotlight, 10 posts, first meetup, 5 meetups, verified). Worked out in the app from `postsBy` and `EventsRepository.attended`, not stored; a server function would be needed to make them tamper-proof.
6. ✅ **Journeys as stories:** a title and an intro ("where it started", `journeys.intro`, editable by the owner), then posts as numbered chapters on a timeline. Shown as story highlights on the profile; the journey chip on a post opens the story.
7. **Push reminders** for events (needs Blaze and Cloud Functions), add-to-calendar, photo consent at events, and showing attendees' first names to other attendees (adults only).
