🎓 ExamFlow: LaTeX-Enabled Examination Platform

ExamFlow is a full-stack Flutter application designed for high-stakes academic and competitive testing. It features real-time synchronization, automatic and manual grading, and robust support for mathematical notation via LaTeX.
🚀 Core Features
👨‍🎓 Student Module

    Token-Based Entry: Secure access via unique exam tokens (examTokens/$id).

    Real-Time Exam Room: * LaTeX Support: Beautifully rendered mathematical questions using LatexText.

        Smart Inputs: Specialized MathAnswerField for equation-based answers.

        Server-Side Timer: Synchronized endTime to prevent local clock manipulation.

    Persistent Progress: Answers are synced to Firebase instantly to protect against crashes.

🛠️ Admin Module

    Exam Builder: Create exams with custom durations and descriptions.

    Question Editor: * Support for MCQ (Single/Multi) and Written/LaTeX types.

        Live Preview: Real-time LaTeX rendering as you type.

    Token Manager: Generate, share (deep-links), and revoke access tokens.

    Manual Grading: Dedicated interface to review and score LaTeX-based written proofs.

🛠️ Tech Stack

    Frontend: Flutter (v3.x)

    State Management: Riverpod

    Navigation: GoRouter (Declarative Routing)

    Backend: Firebase (Authentication & Realtime Database)

    Styling: * Primary Color: #2264D7 (Blue)

        Typography: Inter (via Google Fonts)

        Rendering: Flutter LaTeX for math notation.

📂 Project Structure
Plaintext

lib/
├── models/           # Question, Exam, and Attempt data models
├── providers/        # Riverpod providers for exams and auth state
├── services/         # Firebase logic (AuthService, ExamService, TokenService)
├── screens/
│   ├── admin/        # Dashboard, ExamBuilder, TokenManager, Grading
│   └── student/       # TokenLanding, ExamRoom, ResultScreen
├── widgets/          # LatexText, MathAnswerField, TimerWidget, etc.
├── router.dart       # Central GoRouter configuration
└── main.dart         # Entry point & Global Theme configuration

🔐 Security Configuration

The platform utilizes a server-side "Time Lock" within database.rules.json. This ensures that even if a user bypasses the UI, the database will reject any answer submitted after the endTime timestamp.

    Note: Ensure your admin UID is added to the /users node with "role": "admin" to access management tools.

🛠️ Getting Started

    Clone & Install:
    Bash

git clone [your-repo-url]
flutter pub get

Firebase Setup:

    Run flutterfire configure.

    Apply the rules found in database.rules.json to your Firebase Console.

Run:
Bash

    flutter run

📝 License

Proprietary - Developed by Shamim [2026].