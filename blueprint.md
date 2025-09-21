
# Blueprint

## Overview

This document outlines the plan for developing a Flutter application with Firebase integration. The application will include features for user authentication, a personality quiz, and matching users based on their quiz results.

## Current Plan

### Edit Profile Screen Enhancements

The following features will be added to the Edit Profile screen:

*   **Profile Picture Management:**
    *   Allow users to replace their existing profile picture with a new one from their device's gallery.
    *   Allow users to delete their current profile picture, which will revert to a default placeholder.
*   **Editable Profile Fields:**
    *   **Nickname:** A text field to update the user's nickname.
    *   **Age:** A text field to update the user's age.
    *   **Bio:** A text field to update the user's bio.
*   **Retake Quiz:**
    *   A button that allows users to retake the personality quiz.

### Implementation Steps

1.  **Update `edit_profile_screen.dart`:**
    *   Add UI elements for profile picture replacement and deletion.
    *   Incorporate `TextField` widgets for editing the nickname, age, and bio.
    *   Add a "Retake Quiz" button.
2.  **Update `user_service.dart`:**
    *   Implement a method to handle the uploading of the new profile picture to Firebase Storage and updating the user's profile data in Firestore.
    *   Implement a method to remove the profile picture URL from the user's profile data in Firestore.
    *   Create methods to update the nickname, age, and bio fields in the user's Firestore document.
3.  **Integrate Image Picker:**
    *   Use the `image_picker` package to allow users to select an image from their gallery.
4.  **State Management:**
    *   Use a `ChangeNotifier` or similar state management solution to manage the state of the editable fields and reflect changes in the UI.
5.  **Navigation:**
    *   Configure the "Retake Quiz" button to navigate to the `quiz_intro_screen.dart`.

## Style and Design

*   **Theme:** Modern, clean, and visually appealing.
*   **Color Palette:** A vibrant and energetic color palette will be used to create a positive user experience.
*   **Typography:** Expressive and relevant typography will be used to emphasize key information and create a clear visual hierarchy.
*   **Iconography:** Icons will be used to enhance understanding and navigation.
*   **Interactivity:** Interactive elements will have a "glow" effect to provide visual feedback.

## Features

*   **User Authentication:**
    *   Login and signup screens.
    *   Firebase Authentication for secure user management.
*   **Personality Quiz:**
    *   A multi-question quiz to determine a user's personality type.
*   **User Matching:**
    *   A matching screen that displays users with similar quiz results.
*   **Profile Editing:**
    *   The ability for users to edit their profile information.

