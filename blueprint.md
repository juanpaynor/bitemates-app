
# Bitemates Application Blueprint

## Overview

This document outlines the architecture, features, and design of the Bitemates Flutter application. It serves as a single source of truth for the application's structure and functionality.

## Current Implementation Plan

### Authentication and Routing Flow

When a user opens the app, the `AuthWrapper` widget will check the user's authentication state. 

1.  **If the user is not logged in**, they will be directed to the `BitematesLoginScreen`.
2.  **If the user is logged in**, the app will fetch the user's data from the `users` collection in Firestore.
    *   If the user's document does not exist, or if the `additional_info_completed` flag is `false`, the user will be directed to the `AdditionalInfoScreen`.
    *   If `additional_info_completed` is `true` but the `quiz_completed` flag is `false`, the user will be directed to the `QuizIntroScreen` to complete the personality quiz.
    *   If both `additional_info_completed` and `quiz_completed` are `true`, the user will be directed to the `HomeScreen`.

### Home Screen UI

The home screen provides a central hub for users to find groups, view their current group, and explore other features.

*   **"Find Your Group" Button**: A large, centered button at the top of the screen that initiates the group finding process. When tapped, it navigates to the `/matching` route.
*   **Recent Group Section**: Displays the user's most recent group, including member avatars and a "Go to Chat" button.
*   **Bottom Tabs**:
    *   **Explore Events**: A card that navigates to a section for community-hosted events like dinners and trivia nights.
    *   **Connections**: A card that navigates to a list of the user's saved friends and contacts.

### Matching Screen

When a user taps the "Find Your Group" button, they are taken to the `MatchingScreen`. This screen provides visual feedback while the app searches for compatible bitemates in the background.

*   **Lottie Animation**: A prominent Lottie animation (`searching for profile.json`) is displayed to engage the user during the waiting period.
*   **Descriptive Text**: Text such as "Finding your bitemates..." informs the user of the current process.
*   **Cancel Button**: A "Cancel Search" button allows the user to exit the matching process and return to the previous screen.
*   **Navigation**: The route for this screen is `/matching`.

### Firestore Schema: `users` Collection

This section defines the database schema for the `users` collection in Firestore.

#### Collection Path
`/users`

#### Document ID
The Document ID for each user document should be the user's Firebase Authentication UID.

#### Fields
| Field Name        | Data Type           | Description                                                                                                |
|-------------------|---------------------|------------------------------------------------------------------------------------------------------------|
| `full_name`       | `string`            | The user's full name.                                                                                      |
| `nickname`        | `string`            | The user's chosen nickname.                                                                                |
| `bio`             | `string`            | A short biography of the user (max 150 characters).                                                        |
| `age`             | `number`            | The user's age.                                                                                            |
| `email`           | `string`            | The user's email address (matches the one in Firebase Auth).                                               |
| `quiz_completed`  | `boolean`           | A flag to indicate if the user has completed the initial personality quiz. `true` or `false`.              |
| `additional_info_completed` | `boolean` | A flag to indicate if the user has completed the additional info screen. `true` or `false`.          |
| `created_at`      | `timestamp`         | The server timestamp when the user document was created.                                                   |
| `personality`     | `map`               | A map containing the user's personality traits derived from the quiz.                                      |
| nested `extraversion` | `number`            | A score from 1-10 indicating the user's level of extraversion.                                             |
| nested `chill_factor` | `number`            | A score from 1-10 indicating how "chill" the user is.                                                      |
| nested `openness`   | `number`            | A score from 1-10 indicating the user's openness to new experiences.                                       |
| nested `interests`  | `array` of `string` | A list of the user's selected interests (e.g., "Hiking", "Movies", "Gaming").                              |
| nested `conversation_style` | `string`| Describes the user's preferred style of conversation (e.g., "Deep talks", "Witty banter", "Easygoing"). |


### Example User Document

Here is an example of a user document. You can use this structure to manually create a new document in the Firebase Console for testing.

**Collection:** `users`
**Document ID:** `aLg849...pXfV2m` (This would be the actual Firebase Auth UID)

```json
{
  "full_name": "Jane Doe",
  "nickname": "Janie",
  "bio": "Lover of coffee, music, and spontaneous adventures.",
  "age": 28,
  "email": "jane.doe@example.com",
  "quiz_completed": false,
  "additional_info_completed": true,
  "created_at": "2023-10-27T10:00:00Z",
  "personality": {
    "extraversion": 0,
    "chill_factor": 0,
    "openness": 0,
    "interests": [],
    "conversation_style": ""
  }
}
```

### Recommended Firestore Security Rules (MVP)

These rules provide a secure starting point for your MVP. They ensure that users can only read and write their own data.

You can copy and paste this into the **Rules** tab of your Firestore database in the Firebase Console.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users Collection
    match /users/{userId} {
      // A user can create their own document, read it, and update it.
      // Nobody can delete a user document for this MVP.
      allow read, create, update: if request.auth != null && request.auth.uid == userId;
      allow delete: if false;
    }
  }
}
```
