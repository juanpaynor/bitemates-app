# Project Blueprint: BiteMates

## Overview

BiteMates is a social matching application that connects users by creating small, compatible groups for shared activities. The core of the application is a matching algorithm that uses user-provided quiz data and location information to form these groups.

## Core Features Implemented

*   **Authentication:**
    *   Email & Password signup and login.
    *   Google Sign-In.
*   **User Profile:**
    *   Users can create and edit a profile with their full name, nickname, bio, age, and a profile picture.
    *   Profile pictures are uploaded to Firebase Storage.
*   **Matching Quiz:**
    *   A multi-step quiz captures user personality traits (Extraversion, Chill Factor, Openness), interests, and conversation style.
    *   Quiz answers are stored in the user's Firestore document.
*   **Cloud Function (`createGroups`):**
    *   An HTTPS-triggered function that groups users based on compatibility scores and location (`sector`).
    *   The function is designed to create groups of 5.

## Current Development Plan: Location/Sector Feature

**Objective:** Implement a mandatory location selection for all users to enable location-based matching. This will resolve the current failure in the `createGroups` function and improve match quality.

**Phase 1: Home Screen Prompt**

1.  **Check for `sector` on `HomeScreen`:** When the main screen loads, fetch the user's data from Firestore.
2.  **Display Prompt:** If the `sector` field is missing or empty, show an alert dialog or banner prompting the user to set their location.
3.  **Location Selection UI:** The prompt will lead to a modal dialog with a dropdown menu.
4.  **Dropdown Options:** The dropdown will contain the following locations, which will be mapped to a `sector` (`southies`, `middle`, `northies`):
    *   Muntinlupa/Alabang - `southies`
    *   Las Pinas - `southies`
    *   Paranaque - `southies`
    *   Pasay - `middle`
    *   Makati - `middle`
    *   Manila - `middle`
    *   Taguig - `middle`
    *   Mandaluyong - `middle`
    *   Pasig - `middle`
    *   San Juan - `middle`
    *   Quezon city - `northies`
    *   Marikina - `northies`
    *   South Caloocan - `northies`
    *   Navotas - `northies`
    *   Malabon - `northies`
    *   Valenzuela - `northies`
    *   North Caloocan - `northies`
5.  **Update Firestore:** Upon selection, update the user's document with the chosen `location` and the corresponding `sector`.

**Phase 2: Edit Profile Integration**

1.  **Add Location Field:** Add a dropdown menu for "Location" in the `edit_profile_screen.dart`.
2.  **Functionality:** Allow users to view and update their location at any time. Saving the change will update both the `location` and `sector` fields in their Firestore document.
