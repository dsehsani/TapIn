# Feature Request: Persistent "Attending" System & Temporal Sorting

I want to implement a "Save to Attend" feature for my Campus Events app using **Local Storage** for persistence. Please follow these specifications:

### 1. Functional Logic
* **State Management:** Use `localStorage` to save an array of event IDs that the user is "Attending."
* **Temporal Sorting:** Create a filter system that compares the `eventDate` with the current system date:
    * **Saved Tab:** Display marked events where `eventDate` is today or in the future.
    * **Attended Tab:** Automatically move marked events here once the `eventDate` has passed.
* **Toggle Sync:** The "Attending" status must stay in sync between the **Event Card** (Campus Tab) and the **Expanded Big Card** (Detail View).

### 2. UI/UX Design
* **State A (Not Attending):** A sleek, minimal `+` icon or outline bookmark.
* **State B (Attending):** A vibrant **Green Checkmark** (use a modern brand green like `text-emerald-500` or `text-green-400`).
* **Detail View:** Ensure the "Big Card" has a prominent button to toggle this status.
* **Animation:** Use Tailwind CSS for a subtle scale-up or fade-in effect when the checkmark appears.

### 3. Constraints & Permissions
* **File Creation:** Do NOT create new files or folders without asking me first. If you think a new file (like a custom hook or context provider) is necessary, explain why and wait for my "Go ahead."
* **Code Style:** Keep everything modular and ensure the "Auto-Attended" logic runs whenever the app or the Saved tab is loaded.

Please provide the updated code for the Event components and the storage logic.
