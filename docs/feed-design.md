# Feed design

The feed is where athletes share sporting experiences and get advice from each other. It is built around **helping**, not scrolling: unanswered questions come first, reactions express solidarity rather than popularity, and every design choice keeps young athletes safe. Decisions below were made with the product owner on 20 October 2026. Safeguarding rules also follow `docs/pdpa.md`.

## Home screen

1. **Needs an answer:** open questions, newest first, in the topics the viewer picked. A question leaves this list once its asker marks a reply "This helped me".
2. **Topic tabs:** Injury · Training · Sports nutrition · Competition, each with a picture icon. Members can mute a topic, which hides its tab and its posts.
3. **Filters** (stage 3): by sport and by programme (National / Paralympic / Special Olympics).
4. **Keyword search** (stage 3): post text only. It never searches people, so members stay unsearchable (PDPC children's guidelines).

## Posts

| Type | What it is |
|---|---|
| **Experience** | Sharing what happened ("How I came back from a stress fracture"). |
| **Question** | Asking for advice. Shows **Answered** once the asker marks a reply "This helped me". |
| **Response post** | Either type, written in response to another post (`respondsToId`). It appears in the feed with "In response to: …" and in the original post's comments thread as a linked card. It follows the same permission rules as a reply to that post. |

- **Journeys** work like playlists. A member creates a named journey ("ACL rehab 2026") and tags their posts into it. Others can follow a journey.
- **Media** (built): up to 4 photos or 1 video (60 s) per post.
  - Photos are re-encoded in Dart with no metadata (`cleanPhoto`).
  - Videos are re-exported on iOS with `AVMetadataItemFilter.forSharing()` (native `VideoPrep` in `AppDelegate.swift`), which a test confirmed removes GPS tags. Android video isn't supported yet.
  - Files sit at `media/{id}` in Cloud Storage (asia-southeast1), with the owner in a private `mediaOwners/{id}`, so anonymous posts stay anonymous.
  - Media is only fetched through the rules, never via public download URLs.
  - Under-18s can't add videos until moderator review exists.
- **Anonymous:** the poster can hide their name. Other members see "Anonymous athlete" (or "Anonymous member") with no sport or level, because those could identify someone in a small sport. The author is still recorded privately for moderation and for the author's own edit or delete.
- **Who can reply:** the poster picks **Athletes** (default), **Everyone** or **No replies**.
  - General public members can only reply where the poster chose Everyone.
  - Under-18 posts: see "Adults and under-18s" below.
- **General public members** can read, react and post **Questions**, labelled "Question from the public". They can't post experiences or journeys.

## Comments thread

A post's comments are its replies plus its response posts.
- Replies can be replied to (`parentReplyId`) and show indented, up to three levels.
- Adults can't reply to an under-18's reply, just as for under-18 posts.
- Response posts slot into the thread by time.

## Reactions

- **"Been there"** on any post: "I've had this too". Anyone can react.
- **"Helpful"** on any reply, by anyone. The most helpful replies sort to the top. A standing note reads: *"Helpful means it helped someone. It doesn't mean the person is a qualified coach, doctor or dietitian."*
- The asker can mark one reply **"This helped me"**, which answers the question.

## Safety

- **Topic banners** on every Injury and Sports nutrition post: *"Shared experience, not medical advice. See a doctor, physiotherapist or dietitian."*
- **Help button** on every post, linking to support services (`lib/config/support_config.dart`). Verified 20 Oct 2026: Samaritans of Singapore 1767 (24h), National Mindline 1771 (24h), emergency 995. **Open:** a verified Singapore eating-disorder service.
- **Flagged words** (stage 2): words such as "purging", "skip meals" or "cut weight fast" show the poster support links and hold the post for review.
- **Under-18 Sports nutrition posts** are always reviewed before going live (stage 2). Until review exists, under-18s can't post in Sports nutrition.
- **Moderation** (stage 2): automatic checks first, then a person approves anything uncertain on an in-app moderator screen. Under-18 videos always go to a person.
- **Member tools** (stage 2): report a post or reply, block a member, mute a topic. A post is hidden automatically after several reports until a moderator checks it.

## Adults and under-18s

- Adults **can see** under-18 posts and react to them.
- **Replies from adults to under-18 posts:** off by default; the young athlete can switch it on per post. Every adult reply is reviewed before it appears (stage 2). Until review exists, only under-18s can reply to under-18 posts.
- **No private messages** between adults and under-18s, ever.
- **Following:** adults need the young athlete's approval to follow them or their journeys (stage 3).
- When adult replies launch, update `MinorProtectionsNotice` and the Privacy Notice (both currently promise "only other under-18s can comment"), and bump `privacyNoticeVersion`.

## Profiles and following

- **Own profile (built):** the bottom bar's Profile tab shows the ID card, then **Posts** and **Journeys**.
  - Posts include your anonymous posts, labelled "only you can see it is yours". They're found through your private contributions list.
  - A journey opens as a playlist of its posts, oldest first.
- **Other people's profiles (stage 3):** tapping a name opens their card and posts. Their anonymous posts never appear there.
- Members can follow athletes and journeys (with adult→under-18 approval, as above).

## Notifications (stage 3)

Replies to my post, new posts in journeys I follow, questions I could answer (my sport and topics), and reactions. These start as an in-app bell. Push notifications need a paid Apple Developer account.

## Accessibility and language (stage 4)

- **Easy-read mode:** short sentences, bigger text and icons.
- **Voice posts**, **read aloud**, and **picture icons** for every topic (icons from stage 1).
- **English, Chinese, Malay and Tamil** for the app's own text. Posts stay in the language they're written in. Fluent speakers must check the translations, especially the Privacy Notice and safety copy (PDPC: children must understand them).

## Data model (Firestore, asia-southeast1)

| Path | Readable by | Contents |
|---|---|---|
| `posts/{postId}` | signed-in members | type, topic, text, createdAt, `replyPolicy`, `minorAuthor`, `anonymous`, author card fields (**omitted when anonymous**), journey id and title, `answered`, counters |
| `postAuthors/{postId}` | the author only | `uid`. The private author link, so anonymous posts still have an owner |
| `posts/{postId}/replies/{replyId}` | signed-in members | author card fields, `minorAuthor`, text, `helpfulCount`, `helpedAsker`, optional `parentReplyId` |
| `mediaOwners/{mediaId}` | the owner only | `uid`, `kind`. Checked by `storage.rules` before uploads and deletes |
| `posts/{postId}/beenThere/{uid}` | signed-in members | one doc per reaction (enforces one per person) |
| `posts/{postId}/replies/{replyId}/helpful/{uid}` | signed-in members | one doc per Helpful mark |
| `journeys/{journeyId}` | signed-in members | owner uid, title, createdAt (anonymous posts can't join journeys) |

- Counters (`replyCount`, `beenThereCount`, `helpfulCount`) change by exactly ±1 in the same batch as the matching document. `firestore.rules` checks that with `existsAfter`.
- `minorAuthor` is set when the post is made and never changes, so a post written at 17 keeps its protections.
- Posts never contain date of birth, email or phone.

## Build stages

Navigation: the bottom bar is **Feed · New post · Profile** ("Home · Post · Me" in Easy mode).
- **Posting is video-first.** New post (and Respond with a post) opens `CaptureScreen`: the front camera, ready to record (up to 60 s).
- A **Video · Photo · Text** switch and a **Library** button cover other ways of posting.
- In the standard view, the composer opens after capture with the media attached. A caption can be one word when there's media.
- **Easy mode asks first:** topic → share or ask → *then* the camera (`CaptureScreen(returnMedia: true)`) → a few words → check and post. Closing the camera goes back a step, and "Record again" redoes the clip.
- Under-18s start in Photo mode, with Video disabled until moderation exists.
- With no camera (the simulator, a denied permission, or no answer within 5 s), the screen offers Library and Text instead.

1. **Text feed** (built): Experience and Question posts, journeys (create and tag), topic tabs with icons, Needs an answer, replies with poster controls, anonymous posting, Been there, Helpful plus disclaimer, This helped me, topic banners, help button. Public members ask questions only. Under-18s: replies from under-18s only, and no Sports nutrition posts yet.
2. **Safety:** report, block, mute, auto-hide, flagged words, moderator role and screen, review queues (under-18 nutrition, adult replies to under-18s), automatic moderation. Needs a server function (Blaze plan) and a moderation service.
3. **Social:** other people's profiles, following, filters, search, in-app notifications. (Media, response posts, nested replies and the own profile were brought forward and are built.)
4. **Accessibility and language:** easy-read mode, voice posts, read aloud, translations.
