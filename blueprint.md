# Project Blueprint

## Overview

This document outlines the features, design, and architecture of the BiteMates Flutter application. It serves as a single source of truth for the project's current state.

## Features

- **Authentication:** Users can sign up and log in using Firebase Authentication.
- **Onboarding:** New users are guided through a multi-step onboarding process:
  - **Additional Info:** Users provide their nickname and a profile photo.
  - **Quiz:** Users answer a series of questions to determine their food preferences.
- **Home Screen:** A personalized dashboard that welcomes the user.
- **Navigation:** An updated app drawer provides access to:
  - **Your Profile:** Navigates to a screen where users can edit their profile.
  - **Report a Problem:** A placeholder for a user feedback system.
  - **Sign Out:** Logs the user out of the application.
- **Matching:** Users can initiate a matching process to find other users with similar tastes (UI placeholder).
- **My Group:** A placeholder screen to display the user's group.
- **Profile Editing:** A screen where users can update their profile information.

## Design

- **Theme:** The app uses a custom theme with a brand color of orange (`#xFFFF6B35`).
- **Fonts:** The app uses the Poppins font from `google_fonts`.
- **Layout:** The app uses a clean, modern layout with cards and clear calls to action.

## Architecture

- **State Management:** The app uses the `provider` package for state management, with an `AuthNotifier` to manage the user's authentication and onboarding state.
- **Routing:** The app uses the `go_router` package for declarative routing.
- **Backend:** The app is powered by Firebase, using Firestore to store user data.

## Current Task

**Request:** The user wants to improve the app drawer with three buttons: "Your Profile", "Sign Out", and "Report a Problem".

**Plan:**

1.  **DONE:** Modify `lib/app_drawer.dart` to include the three new buttons and their associated functionality.
2.  **DONE:** Add a new route for `/edit-profile` in `lib/app_router.dart`.
3.  **DONE:** Update this `blueprint.md` file to reflect the changes.
