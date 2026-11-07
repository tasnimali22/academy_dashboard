# Coding Academy Admin

Flutter/Firebase admin app for managing courses, exams, student access, and attendance.

## Firestore data used by both apps

- `courses/{courseId}` stores a course. Lessons are stored below
  `courses/{courseId}/lessons` with `title`, `videoId`, and `order`.
- `exams/{examId}` stores `title`, `courseId`, `questionsCount`,
  `durationMinutes`, `date`, `icon`, and `order`. Exam questions are stored
  below `exams/{examId}/questions` with `text`, `options`, `correctIndex`, and
  `order`.
- `users/{uid}` stores the student profile and the `courseIds` and `examIds`
  lists that control what the student app displays.
- `attendance/{courseId-YYYYMMDD}` stores `courseId`, `date`, and a `records`
  map keyed by student UID. Each record is `true` for present and `false` for
  absent.
- Admin accounts must have a document in `admins/{uid}`.

New students are added to `users` when they sign up or next log in. Assign
course and exam access from **الطلاب والصلاحيات** in the admin dashboard.
