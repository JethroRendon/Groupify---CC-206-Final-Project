Groupify – Academic Group Project Management App
Final Project for CC 206: Application Development and Emerging Technologies

Groupify is a mobile application designed to streamline student collaboration in academic group projects. Many students rely on separate tools for communication, file sharing, and task tracking, which leads to fragmented workflows and disorganized project management. Groupify addresses this problem by providing a unified, student-centered platform that integrates task management, file organization, and group coordination in one system.

🖥 How to Run the Application

Before using the mobile app, ensure that the backend is running.
Use the terminal in Visual Studio Code and follow these steps:

cd groupify-backend
npm start


Make sure that the mobile application is already running beforehand.

📌 Features
✔ Project & Group Management

Create groups and manage members

Join groups using a code

Organized project workspaces

✔ Task Management

Assign tasks to specific members

View and track task progress using stages (To Do, In Progress, Done)

Set deadlines and receive reminders

✔ File Sharing

Upload documents, images, videos, and other file types

View categorized file repositories

Access recent uploads easily

✔ User Profile & Settings

Edit profile details

Manage notification preferences

Adjust privacy and general settings

✔ Real-Time Synchronization

Firebase ensures live updates across all devices

Supports online and offline access with local caching

🛠 Technology Stack
Frontend (Client-Side)

Flutter (Dart) – Cross-platform mobile development

Provider / Riverpod – State management (depending on implementation)

Backend (Firebase Services)

Firebase Authentication – User login and credential handling

Cloud Firestore – NoSQL database for users, groups, tasks, and metadata

Cloud Storage – File handling for documents and media

Cloud Functions – Backend logic and automated triggers

Firebase Cloud Messaging (FCM) – Push notifications

👥 Developers

Justin Jones Brey
Jethro Rendon
