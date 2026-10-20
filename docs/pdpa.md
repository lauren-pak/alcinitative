# PDPA checklist

How Athlete App handles personal data under Singapore's Personal Data Protection Act 2012, including the PDPC's *Advisory Guidelines on the PDPA for Children's Personal Data in the Digital Environment* (28 March 2024). Athlete App is a social service likely to be used by children (under 18), so those guidelines apply.

This is an engineering checklist, not legal advice. Have it reviewed before launch.

## What the app does

| Obligation | How it's met | Where |
|---|---|---|
| **Consent** | People agree to the Privacy Notice before any personal data is collected; the role buttons are disabled until they do. The notice version and time are saved with the profile. | `RoleStep`, `users/{uid}.consent` |
| **Consent: children** | Under-13s can't sign up (they'd need a parent's consent, guidelines 4.5). 13–17s may consent themselves if the notice is understandable (4.2), so it's written in plain language and tells them to read it with a parent if unsure. | `AboutStep`, `firestore.rules`, `PrivacyNoticeScreen` |
| **Notification** | Plain-language Privacy Notice: what is collected, why, who sees it, where it's stored, how long, how to access, correct and delete. | `PrivacyNoticeScreen` |
| **Purpose limitation** | Data is only used to run accounts, show ID cards, apply under-18 protections and pick feed topics. No ads, no selling. | Privacy Notice |
| **Withdrawal of consent** | "Delete my account" removes the profile, ID card and sign-in, as easily as signing up (guidelines 4.4). Abandoned sign-ups delete their half-made sign-in. | `YourDataScreen`, `SignUpFlow` |
| **Access** | "Your data & privacy" shows everything stored, with a download. | `YourDataScreen` |
| **Correction** | Members edit name, sport, level, programme and topics. Date of birth goes through the DPO, because it controls under-18 protections. | `EditProfileScreen`, `firestore.rules` |
| **Data minimisation** | Only what's needed: no location, no address, no national ID. Email, phone and passwords stay in Firebase Auth, never in the profile database. | `FirestoreProfileRepository` |
| **Children not public or searchable by default** | ID cards can only be fetched by exact ID, never listed or searched. Under-18 cards are hidden from adults, who get the same "not found" as for a missing ID. Date of birth is never on the card. | `firestore.rules`, `AthleteIdCard` |
| **Protection** (children's data treated as sensitive) | Security rules enforced on Google's servers: owner-only profiles, field validation, date of birth and consent can't be edited, the 18th birthday can't be faked. Passwords are handled by Firebase Auth. | `firestore.rules` |
| **Transfer limitation** | Firestore is in `asia-southeast1` (Singapore). | Firebase console |
| **Retention** | Data is kept while the account is open and deleted with it. | `YourDataScreen` |

## Still to do before real users

- [ ] **Appoint a Data Protection Officer** and put their email in `dataProtectionOfficerEmail` (`lib/config/privacy_config.dart`). The PDPA requires this, and the Privacy Notice shows it.
- [ ] **Legal review** of the Privacy Notice wording.
- [ ] **Data Protection Impact Assessment (DPIA)**: the guidelines recommend one before launching a service children use. Annex A of the guidelines lists the questions.
- [ ] **Data breach response plan**: assess within 30 days; notify the PDPC within 3 days and affected people when notifiable. For children, explain simply and suggest they tell a parent (guidelines section 6).
- [ ] **Google Cloud data processing terms**: accept them in the Firebase / Google Cloud console (Google is the data intermediary).
- [ ] **Admin access**: turn on 2-step verification for every Google account with access to the Firebase project (guidelines "Enhanced Practices").
- [ ] **Firestore backups and retention**: decide whether to enable backups, and if so how long they're kept, and add that to the notice.
- [ ] **Inactive accounts**: decide on a retention period for unused accounts (this needs a scheduled Cloud Function).
- [ ] **Videos** (when posts are built): strip location metadata, and keep under-18 videos in review before they go live, as `MinorProtectionsNotice` promises.
- [ ] Bump `privacyNoticeVersion` whenever the notice changes, and ask existing members to agree again.
