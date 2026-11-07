# Coding Academy Admin

Flutter/Firebase admin app for managing courses, exams, student access, and attendance.

## Firestore data used by both apps

- `courses/{courseId}` stores a course, including `createdBy` (the admin UID).
  Admins can read and manage only courses they created; Super Admins can
  manage all courses. Lessons inherit the parent course's ownership.
- Lessons are stored below
  `courses/{courseId}/lessons` with `title`, `videoId`, and `order`.
- `exams/{examId}` stores `title`, `courseId`, `questionsCount`,
  `durationMinutes`, `date`, `icon`, `order`, and `createdBy`. Admins can
  create exams only for their own courses and cannot read another admin's
  exams. Questions below `exams/{examId}/questions` contain `text`, `options`,
  and `order`; private correct answers are in
  `exams/{examId}/answerKeys/{questionId}`. Both inherit the exam's ownership.
- `users/{uid}` stores the student profile and the `courseIds` and `examIds`
  lists that control what the student app displays.
- `attendance/{courseId-YYYYMMDD}` stores `courseId`, `date`, and a `records`
  map keyed by student UID, plus `createdBy`. Admins can manage attendance
  only for their own courses.
- `appointments/{appointmentId}` stores `courseId` and `createdBy`. Students
  see appointments only for courses assigned to them; admins see only
  appointments they created.
- `admins/{uid}` stores the role as `admin` or `superAdmin`. Existing admin
  documents without a role are treated as `admin`. The initial Super Admin is
  `tasnimali051@gmail.com`; only Super Admins can change roles or student access.

New students are added to `users` when they sign up or next log in. Assign
course and exam access from **الطلاب والصلاحيات** in the admin dashboard,
which is available to Super Admins only. Content created before ownership
tracking was added remains visible to Super Admins; it is not shown to regular
admins unless its ownership is assigned.

Admin separation and role assignment use Firestore security rules and the
Firebase client SDK; they do not require Cloud Functions or the Blaze plan.
Deploy only the Firestore rules from the student project directory:

```shell
firebase deploy --only firestore:rules --project code-acadmy
```
