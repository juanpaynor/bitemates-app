# BiteMates App Blueprint

## Overview

BiteMates is a social application designed to connect users with similar food preferences. It facilitates finding dining partners and forming groups for shared meals. The app includes features like a food preference quiz, user matching, group chat, and profile customization.

## Implemented Features

*   **Authentication:** User login and signup screens.
*   **Onboarding:** A multi-step quiz to capture user's food preferences, dietary restrictions, and eating habits.
*   **User Matching:** A matching screen that displays potential dining partners based on quiz results.
*   **Group Formation:** Users can form groups with their matches.
*   **Group Chat:** A chat interface for communication within a group.
*   **Profile Management:** Users can view and edit their profile information.
*   **Settings:** A settings screen for application-level configurations.
*   **Navigation:** A drawer-based navigation system to switch between different sections of the app.

## Current Plan: Codebase Analysis and Remediation

The following plan outlines the steps to address the issues identified by the `flutter analyze` command. The goal is to improve code quality, fix potential bugs, and ensure the long-term maintainability of the application.

### 1. Fix Critical `use_build_context_synchronously` Warnings

This is the highest priority to prevent potential application crashes. I will add `mounted` checks before using `BuildContext` after an asynchronous operation in the following files:

*   `lib/bitemates_login_screen.dart`
*   `lib/home_screen.dart`
*   `lib/my_group_screen.dart`
*   `lib/settings_screen.dart`

### 2. Replace Deprecated Code

To ensure future compatibility and adhere to best practices, I will replace all deprecated members:

*   **`withOpacity`:** Replace with `.withValues()` in:
    *   `lib/additional_info_screen.dart`
    *   `lib/edit_profile_screen.dart`
*   **`TextFormField.value`:** Replace with `initialValue` in:
    *   `lib/edit_profile_screen.dart`
    *   `lib/home_screen.dart`

### 3. Improve Error Handling and Logging

I will enhance the application's logging and error handling mechanisms:

*   **Replace `print` with `developer.log`:** For better debugging and to remove `avoid_print` warnings in:
    *   `lib/bitemates_login_screen.dart`
    *   `lib/services/chat_service.dart`
*   **Use `rethrow` for exceptions:** To preserve the original stack trace in `lib/services/chat_service.dart`.

### 4. Code Refactoring and Cleanup

I will address the remaining warnings to improve code quality and readability:

*   **Refactor `library_private_types_in_public_api`:** Fix the private type exposure in `lib/my_group_screen.dart`.
*   **Remove Unused Code:**
    *   Remove unused imports in `lib/additional_info_screen.dart` and `lib/user_service.dart`.
    *   Remove the unused `brandOrange` variable in `lib/settings_screen.dart`.
    *   Remove the unnecessary import in `lib/user_service.dart`.

By following this plan, I will systematically improve the codebase, making it more robust, stable, and easier to maintain.
