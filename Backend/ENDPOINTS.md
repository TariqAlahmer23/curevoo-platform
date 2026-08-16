# Curevoo Endpoints

This file is synced to the routes currently mounted in [src/app.js](c:\Users\96566\Desktop\Curevoo\src\app.js#L1).

## Totals

- Total routes: `128`
- HTTP endpoints: `127`
- Static file route: `1` (`GET /uploads/<path>`)

## Access Lists

### All ADMIN Endpoints (Single List)

- `GET /api/admin/knowledge-articles`
- `GET /api/admin/knowledge-articles/:id`
- `GET /api/admin/knowledge-articles/:id/metadata`
- `POST /api/admin/knowledge-articles`
- `PUT /api/admin/knowledge-articles/:id`
- `DELETE /api/admin/knowledge-articles/:id`
- `GET /api/admin/users/doctors`
- `POST /api/admin/users/doctors`
- `PUT /api/admin/users/doctors/:userId`
- `DELETE /api/admin/users/doctors/:userId`
- `GET /api/admin/users/patients`
- `POST /api/admin/users/patients`
- `PUT /api/admin/users/patients/:userId`
- `DELETE /api/admin/users/patients/:userId`
- `POST /api/registration/create-account` (only when creating `role=ADMIN`, requires authenticated `ADMIN`)

### All PUBLIC Endpoints (Single List)

- `GET /health`
- `GET /uploads/<path>`
- `POST /api/auth/register`
- `POST /api/auth/register-doctor`
- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`
- `POST /api/registration/create-account` (for `role=PATIENT` or `role=DOCTOR`)
- `POST /api/registration/verify-email/send-otp`
- `POST /api/registration/verify-email/confirm`
- `POST /api/registration/login`
- `POST /api/registration/refresh`
- `POST /api/registration/forgot-password/send-otp`
- `POST /api/registration/forgot-password/reset`
- `POST /api/patients/register`
- `POST /api/patients/login`
- `POST /api/patients/refresh`
- `POST /api/patients/forgot-password/send-otp`
- `POST /api/patients/forgot-password/reset`

## Cluster Map

1. Platform and Static Assets: `2`
2. Authentication Core: `6`
3. Unified Registration, Recovery, and Account Lifecycle: `10`
4. QR, Notifications, and Doctor-Patient Relationship Workflows: `12`
5. Patient Account and Self-Service: `10`
6. Doctor Directory for Patients: `3`
7. Patient Appointments: `5`
8. Doctor Appointment Review: `10`
9. Doctor Self-Service and Availability: `29`
10. Patient Care and Medical Records: `8`
11. Doctor Care and Medical Records: `16`
12. AI Diagnosis and Resistance Workflows: `7`
13. Psychological Support and Knowledge Workflows: `10`

---

## 1. Platform and Static Assets

### GET `/health`
- Auth: Public
- Purpose: Health check endpoint.
- Example: `GET http://localhost:5432/health`

### GET `/uploads/<path>`
- Auth: Public
- Purpose: Serves uploaded static files such as doctor photos and medical-record images.
- Example: `GET http://localhost:5432/uploads/doctors/sample.jpg`
- Example: `GET http://localhost:5432/uploads/medical-records/sample-mri.jpg`

---

## 2. Authentication Core

### POST `/api/auth/register`
- Auth: Public
- Purpose: Register a patient through the auth module.
- Example:
```json
{
  "email": "patient1@example.com",
  "password": "Pass1234!",
  "fullName": "Patient One"
}
```

### POST `/api/auth/register-doctor`
- Auth: Public
- Purpose: Register a doctor through the auth module.
- Example: `multipart/form-data` with `name=Dr. Samer`, `email=doctor@example.com`, `password=Pass1234!`, `phoneNumber=+963944000000`, `age=40`, `specialization=Oncology`, `workplace=City Hospital`, `experience=10`, `location=Damascus`, `languages=["ar","en"]`

### POST `/api/auth/login`
- Auth: Public
- Purpose: Login through the auth module.
- Example:
```json
{
  "email": "patient1@example.com",
  "password": "Pass1234!"
}
```

### GET `/api/auth/validate-token`
- Auth: Any authenticated role
- Purpose: Validate access token.
- Example: `GET /api/auth/validate-token` with `Authorization: Bearer {{accessToken}}`

### POST `/api/auth/refresh`
- Auth: Public
- Purpose: Refresh access token.
- Example:
```json
{
  "refreshToken": "{{refreshToken}}"
}
```

### POST `/api/auth/logout`
- Auth: Public
- Purpose: Clear refresh token cookie.
- Example: `POST /api/auth/logout`

---

## 3. Unified Registration, Recovery, and Account Lifecycle

### POST `/api/registration/create-account`
- Auth: Public for `PATIENT` and `DOCTOR`, authenticated `ADMIN` for admin creation
- Purpose: Unified account creation endpoint.
- Example:
```json
{
  "email": "newpatient@example.com",
  "password": "Pass1234!",
  "fullName": "New Patient",
  "role": "PATIENT"
}
```

### POST `/api/registration/verify-email/send-otp`
- Auth: Public
- Purpose: Send email verification OTP.
- Example:
```json
{
  "email": "newpatient@example.com"
}
```

### POST `/api/registration/verify-email/confirm`
- Auth: Public
- Purpose: Confirm email verification OTP.
- Example:
```json
{
  "email": "newpatient@example.com",
  "otp": "123456"
}
```

### POST `/api/registration/login`
- Auth: Public
- Purpose: Login alias under registration.
- Example:
```json
{
  "email": "doctor@example.com",
  "password": "Pass1234!"
}
```

### POST `/api/registration/refresh`
- Auth: Public
- Purpose: Refresh token alias under registration.
- Example:
```json
{
  "refreshToken": "{{refreshToken}}"
}
```

### POST `/api/registration/forgot-password/send-otp`
- Auth: Public
- Purpose: Send password reset OTP.
- Example:
```json
{
  "email": "doctor@example.com"
}
```

### POST `/api/registration/forgot-password/reset`
- Auth: Public
- Purpose: Reset password with OTP.
- Example:
```json
{
  "email": "doctor@example.com",
  "otp": "123456",
  "newPassword": "NewPass1234!"
}
```

### POST `/api/registration/change-password`
- Auth: Any authenticated role
- Purpose: Change password while logged in by providing the current password.
- Example:
```json
{
  "currentPassword": "Pass1234!",
  "newPassword": "NewPass1234!"
}
```

### DELETE `/api/registration/delete-account`
- Auth: Any authenticated role
- Purpose: Delete account or create patient deletion requests when needed.
- Example: `DELETE /api/registration/delete-account` with `Authorization: Bearer {{accessToken}}`

### POST `/api/registration/logout`
- Auth: Any authenticated role
- Purpose: Logout alias under registration.
- Example: `POST /api/registration/logout` with `Authorization: Bearer {{accessToken}}`

---

## 4. QR, Notifications, and Doctor-Patient Relationship Workflows

### GET `/api/registration/my-qr`
- Auth: `PATIENT` or `DOCTOR`
- Purpose: Return the signed-in user's QR payload.
- Example: `GET /api/registration/my-qr` with `Authorization: Bearer {{accessToken}}`

### GET `/api/registration/notifications`
- Auth: Any authenticated role
- Purpose: Return user notifications.
- Example: `GET /api/registration/notifications` with `Authorization: Bearer {{accessToken}}`

### POST `/api/registration/doctor/created-patient`
- Auth: `DOCTOR`
- Purpose: Create a doctor-owned `CreatedPatient` record.
- Example:
```json
{
  "fullName": "Archived Patient",
  "age": 67,
  "sex": "FEMALE",
  "medicalHistory": "Diabetes and hypertension",
  "riskFactors": {
    "smoking": false,
    "familyHistory": true
  }
}
```

### POST `/api/registration/doctor/qr/regenerate`
- Auth: `DOCTOR`
- Purpose: Regenerate doctor QR payload.
- Example: `POST /api/registration/doctor/qr/regenerate` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/registration/doctor/active-patients`
- Auth: `DOCTOR`
- Purpose: Return active linked patients for the doctor.
- Example: `GET /api/registration/doctor/active-patients` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/registration/doctor/created-patients`
- Auth: `DOCTOR`
- Purpose: Return doctor-owned created patients.
- Example: `GET /api/registration/doctor/created-patients` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/registration/doctor/deletion-requests`
- Auth: `DOCTOR`
- Purpose: Return patient deletion requests assigned to the doctor.
- Example: `GET /api/registration/doctor/deletion-requests` with `Authorization: Bearer {{doctorAccessToken}}`

### POST `/api/registration/doctor/deletion-requests/:requestId/respond`
- Auth: `DOCTOR`
- Purpose: Resolve a patient deletion request.
- Example:
```json
{
  "action": "KEEP_AS_CREATED_PATIENT"
}
```

### GET `/api/registration/doctor/connect-requests`
- Auth: `DOCTOR`
- Purpose: Return patient connection requests assigned to the doctor.
- Example: `GET /api/registration/doctor/connect-requests` with `Authorization: Bearer {{doctorAccessToken}}`

### POST `/api/registration/doctor/connect-requests/:requestId/respond`
- Auth: `DOCTOR`
- Purpose: Accept or reject a patient connection request.
- Example:
```json
{
  "action": "ACCEPT"
}
```

### POST `/api/registration/scan/doctor-qr`
- Auth: `PATIENT`
- Purpose: Scan doctor QR and create or refresh a pending request.
- Example:
```json
{
  "qrCode": "curevoo:doctor:cm_doctor_user_id:generated-token"
}
```

### POST `/api/registration/scan/patient-qr`
- Auth: `DOCTOR`
- Purpose: Scan patient QR and link patient directly to doctor.
- Example:
```json
{
  "qrCode": "curevoo:patient:cm_patient_user_id:generated-token"
}
```

---

## 5. Patient Account and Self-Service

### POST `/api/patients/register`
- Auth: Public
- Purpose: Register a patient through the patient module.
- Example:
```json
{
  "email": "patient2@example.com",
  "password": "Pass1234!",
  "fullName": "Patient Two"
}
```

### POST `/api/patients/login`
- Auth: Public
- Purpose: Login through the patient module.
- Example:
```json
{
  "email": "patient2@example.com",
  "password": "Pass1234!"
}
```

### POST `/api/patients/refresh`
- Auth: Public
- Purpose: Refresh token through the patient module.
- Example:
```json
{
  "refreshToken": "{{refreshToken}}"
}
```

### GET `/api/patients/validate-token`
- Auth: `PATIENT`
- Purpose: Validate patient access token.
- Example: `GET /api/patients/validate-token` with `Authorization: Bearer {{patientAccessToken}}`

### POST `/api/patients/forgot-password/send-otp`
- Auth: Public
- Purpose: Send patient password reset OTP.
- Example:
```json
{
  "email": "patient2@example.com"
}
```

### POST `/api/patients/forgot-password/reset`
- Auth: Public
- Purpose: Reset patient password with OTP.
- Example:
```json
{
  "email": "patient2@example.com",
  "otp": "123456",
  "newPassword": "NewPass1234!"
}
```

### POST `/api/patients/change-password`
- Auth: `PATIENT`
- Purpose: Change patient password while logged in by providing the current password.
- Example:
```json
{
  "currentPassword": "Pass1234!",
  "newPassword": "NewPass1234!"
}
```

### POST `/api/patients/logout`
- Auth: `PATIENT`
- Purpose: Logout patient and clear refresh token cookie.
- Example: `POST /api/patients/logout` with `Authorization: Bearer {{patientAccessToken}}`

### GET `/api/patients/me`
- Auth: `PATIENT`
- Purpose: Return signed-in patient profile including `id`, `name`, `email`, `phoneNumber`, `location`, and `sex`.
- Example: `GET /api/patients/me` with `Authorization: Bearer {{patientAccessToken}}`

### GET `/api/patients/dashboard/summary`
- Auth: `PATIENT`
- Purpose: Return patient dashboard summary with 2 key metrics.
- Response highlights:
  - `upcomingAppointments`
  - `latestAiResult` (latest successful NSCLC result, or `null`)
- Example: `GET /api/patients/dashboard/summary` with `Authorization: Bearer {{patientAccessToken}}`

### PUT `/api/patients/me`
- Auth: `PATIENT`
- Purpose: Update signed-in patient profile. Supports `location` as an alias for `address`.
- Example:
```json
{
  "fullName": "Patient Two",
  "location": "Damascus",
  "age": 31,
  "sex": "MALE"
}
```

---

## 6. Doctor Directory for Patients

### GET `/api/doctors`
- Auth: `PATIENT`
- Purpose: Return active doctors with optional filtering. If `limit` is omitted, all matching doctors are returned.
- Example: `GET /api/doctors?specialization=Oncology` with `Authorization: Bearer {{patientAccessToken}}`

### GET `/api/doctors/:id`
- Auth: `PATIENT`
- Purpose: Return one active doctor profile with availability.
- Example: `GET /api/doctors/{{doctorProfileId}}` with `Authorization: Bearer {{patientAccessToken}}`

### GET `/api/doctors/:id/available-times/day`
- Auth: `PATIENT`
- Purpose: Return the selected day's doctor availability plus already booked times for that date.
- Query params: `date=YYYY-MM-DD`
- Example: `GET /api/doctors/{{doctorProfileId}}/available-times/day?date=2026-05-01` with `Authorization: Bearer {{patientAccessToken}}`

---

## 7. Patient Appointments

### POST `/api/patients/appointments`
- Auth: `PATIENT`
- Purpose: Book appointment request. The appointment is created in `PENDING` status and must be approved by the doctor before it becomes `CONFIRMED`.
- Error: returns `409 APPOINTMENT_CONFLICT` with message `Selected time is already booked` if the slot is already occupied.
- Example:
```json
{
  "doctorUserId": "cm_doctor_user_id_here",
  "appointmentDate": "2026-05-01",
  "appointmentTime": "09:30",
  "reason": "Follow-up",
  "notes": "Pain became stronger in the last week"
}
```

### GET `/api/patients/appointments`
- Auth: `PATIENT`
- Purpose: List patient appointments across `PENDING`, `CREATED`, `CONFIRMED`, and `CANCELED` statuses.
- Example: `GET /api/patients/appointments` with `Authorization: Bearer {{patientAccessToken}}`

### PUT `/api/patients/appointments/:id`
- Auth: `PATIENT`
- Purpose: Edit patient appointment. If the patient changes the scheduled day/time, the appointment goes back to `PENDING` so the doctor can approve the new booking time.
- Example:
```json
{
  "appointmentDate": "2026-05-03",
  "appointmentTime": "10:00",
  "reason": "Updated follow-up reason"
}
```

### POST `/api/patients/appointments/:id/cancel`
- Auth: `PATIENT`
- Purpose: Cancel patient appointment.
- Example: `POST /api/patients/appointments/{{appointmentId}}/cancel` with `Authorization: Bearer {{patientAccessToken}}`

### DELETE `/api/patients/appointments/:id`
- Auth: `PATIENT`
- Purpose: Delete patient appointment.
- Example: `DELETE /api/patients/appointments/{{appointmentId}}` with `Authorization: Bearer {{patientAccessToken}}`

---

## 8. Doctor Appointment Review

### POST `/api/doctor/appointments`
- Auth: `DOCTOR`
- Purpose: Create an appointment directly as the doctor for either a linked normal patient or a doctor-created patient. Doctor-created bookings are saved in `CREATED` status.
- Error: returns `409 APPOINTMENT_CONFLICT` with message `Selected time is already booked` if the slot is already occupied.
- Example:
```json
{
  "patientId": "cm_patient_or_created_patient_id",
  "patientType": "NORMAL",
  "appointmentDate": "2026-05-01",
  "appointmentTime": "09:30",
  "reason": "Clinic follow-up",
  "notes": "Booked by doctor from dashboard"
}
```

### GET `/api/doctor/appointments`
- Auth: `DOCTOR`
- Purpose: List doctor appointments.
- Query params: `status=PENDING|CREATED|CONFIRMED|CANCELED|ALL`
- Example: `GET /api/doctor/appointments?status=PENDING` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/appointments/accepted`
- Auth: `DOCTOR`
- Purpose: List accepted doctor appointments in `CONFIRMED` status.
- Example: `GET /api/doctor/appointments/accepted` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/appointments/created`
- Auth: `DOCTOR`
- Purpose: List doctor-created appointments in `CREATED` status.
- Example: `GET /api/doctor/appointments/created` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/appointments/canceled`
- Auth: `DOCTOR`
- Purpose: List canceled doctor appointments.
- Example: `GET /api/doctor/appointments/canceled` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/appointments/pending`
- Auth: `DOCTOR`
- Purpose: List pending doctor appointments that still need a response.
- Example: `GET /api/doctor/appointments/pending` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/appointments/upcoming`
- Auth: `DOCTOR`
- Purpose: List upcoming future doctor appointments across `PENDING`, `CREATED`, and `CONFIRMED` statuses, ordered by scheduled time.
- Example: `GET /api/doctor/appointments/upcoming` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/appointments/booked-slots`
- Auth: `DOCTOR`
- Purpose: Return booked appointment days and times for the doctor. Pending, created, and confirmed appointments are included so the frontend can block occupied slots.
- Query params: `date=YYYY-MM-DD` or `from=YYYY-MM-DD&to=YYYY-MM-DD`
- Example: `GET /api/doctor/appointments/booked-slots?from=2026-05-01&to=2026-05-07` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/appointments/booked-slots/:id`
- Auth: `DOCTOR`
- Purpose: Return one booked slot details item by appointment id when it exists for the signed-in doctor.
- Example: `GET /api/doctor/appointments/booked-slots/{{appointmentId}}` with `Authorization: Bearer {{doctorAccessToken}}`

### POST `/api/doctor/appointments/:id/respond`
- Auth: `DOCTOR`
- Purpose: Approve or reject pending appointment. Approve changes the status to `CONFIRMED`; reject changes it to `CANCELED`.
- Example:
```json
{
  "action": "approve"
}
```

---

## 9. Doctor Self-Service and Availability

### GET `/api/doctor/profile`
- Auth: `DOCTOR`
- Purpose: Return doctor profile.
- Example: `GET /api/doctor/profile` with `Authorization: Bearer {{doctorAccessToken}}`

### PUT `/api/doctor/profile`
- Auth: `DOCTOR`
- Purpose: Update doctor profile.
- Example:
```json
{
  "fullName": "Dr. Samer Al Ali",
  "specialization": "Oncology",
  "workingAt": "Damascus Cancer Center"
}
```

### POST `/api/doctor/photo`
- Auth: `DOCTOR`
- Purpose: Upload doctor photo.
- Example: `multipart/form-data` with `photo=@doctor.jpg`

### PUT `/api/doctor/photo`
- Auth: `DOCTOR`
- Purpose: Replace doctor photo.
- Example: `multipart/form-data` with `photo=@doctor-new.jpg`

### POST `/api/doctor/profile/qr/regenerate`
- Auth: `DOCTOR`
- Purpose: Regenerate doctor QR from doctor namespace.
- Example: `POST /api/doctor/profile/qr/regenerate` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/settings`
- Auth: `DOCTOR`
- Purpose: Return doctor settings.
- Example: `GET /api/doctor/settings` with `Authorization: Bearer {{doctorAccessToken}}`

### PUT `/api/doctor/settings`
- Auth: `DOCTOR`
- Purpose: Update doctor settings.
- Example:
```json
{
  "language": "en",
  "notificationsEnabled": true
}
```

### GET `/api/doctor/patients`
- Auth: `DOCTOR`
- Purpose: Return unified doctor patient list for normal and created patients.
- Example: `GET /api/doctor/patients` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/dashboard/summary`
- Auth: `DOCTOR`
- Purpose: Return doctor dashboard summary with 4 recommended metrics.
- Response highlights:
  - `totalPatients`
  - `upcomingAppointments`
  - `pendingAppointments`
  - `latestAiPredictionAt`
- Example: `GET /api/doctor/dashboard/summary` with `Authorization: Bearer {{doctorAccessToken}}`

### POST `/api/doctor/patients`
- Auth: `DOCTOR`
- Purpose: Create a doctor-owned `CreatedPatient` record from doctor namespace.
- Example:
```json
{
  "fullName": "Research Patient",
  "age": 54,
  "sex": "MALE",
  "medicalHistory": "Historical case",
  "riskFactors": {
    "familyHistory": false
  }
}
```

### GET `/api/doctor/patients/:patientId`
- Auth: `DOCTOR`
- Purpose: Return one doctor patient record, whether linked or doctor-created.
- Example: `GET /api/doctor/patients/{{patientId}}` with `Authorization: Bearer {{doctorAccessToken}}`

### PUT `/api/doctor/patients/:patientId`
- Auth: `DOCTOR`
- Purpose: Update a doctor-created patient. Full and partial payloads are both accepted.
- Example:
```json
{
  "fullName": "Updated Research Patient",
  "age": 55,
  "medicalHistory": "Updated historical case"
}
```

### PATCH `/api/doctor/patients/:patientId`
- Auth: `DOCTOR`
- Purpose: Partially update a doctor-created patient.
- Example:
```json
{
  "phoneNumber": "+963944000001"
}
```

### DELETE `/api/doctor/patients/:patientId`
- Auth: `DOCTOR`
- Purpose: Delete a doctor-created patient that has no linked account.
- Example: `DELETE /api/doctor/patients/{{patientId}}` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/patients/:patientId/medical-history`
- Auth: `DOCTOR`
- Purpose: Return patient medical history by patient id. Supports either a linked patient `User.id` or a doctor-created `CreatedPatient.id`. Uploaded scan URLs are returned inside `record.images` when present.
- Example: `GET /api/doctor/patients/{{patientId}}/medical-history` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/patients/:patientId/medical-history/latest`
- Auth: `DOCTOR`
- Purpose: Return only the latest patient medical history record by patient id.
- Example: `GET /api/doctor/patients/{{patientId}}/medical-history/latest` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/patients/:patientId/medical-history/all`
- Auth: `DOCTOR`
- Purpose: Return all patient medical history records by patient id.
- Example: `GET /api/doctor/patients/{{patientId}}/medical-history/all` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/patients/:patientId/medical-records`
- Auth: `DOCTOR`
- Purpose: Return patient medical records by patient id.
- Example: `GET /api/doctor/patients/{{patientId}}/medical-records` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/patients/:patientId/medical-records/latest`
- Auth: `DOCTOR`
- Purpose: Return only the latest patient medical record by patient id.
- Example: `GET /api/doctor/patients/{{patientId}}/medical-records/latest` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/patients/:patientId/medical-records/all`
- Auth: `DOCTOR`
- Purpose: Return all patient medical records by patient id.
- Example: `GET /api/doctor/patients/{{patientId}}/medical-records/all` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/patients/:patientId/treatment-plans`
- Auth: `DOCTOR`
- Purpose: Return patient treatment plans by patient id. Supports either a linked patient `User.id` or a doctor-created `CreatedPatient.id`.
- Example: `GET /api/doctor/patients/{{patientId}}/treatment-plans` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/patients/:patientId/treatment-plans/latest`
- Auth: `DOCTOR`
- Purpose: Return only the latest patient treatment plan by patient id.
- Example: `GET /api/doctor/patients/{{patientId}}/treatment-plans/latest` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/patients/:patientId/treatment-plans/all`
- Auth: `DOCTOR`
- Purpose: Return all patient treatment plans by patient id.
- Example: `GET /api/doctor/patients/{{patientId}}/treatment-plans/all` with `Authorization: Bearer {{doctorAccessToken}}`

### POST `/api/doctor/available-times`
- Auth: `DOCTOR`
- Purpose: Create doctor availability slot.
- Example:
```json
{
  "dayOfWeek": 1,
  "from": "09:00",
  "to": "13:00",
  "isOn": true
}
```

### GET `/api/doctor/available-times`
- Auth: `DOCTOR`
- Purpose: List the doctor's weekly availability as seven days with `dayOfWeek`, `from`, `to`, and `isOn`.
- Example: `GET /api/doctor/available-times` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/available-times/day`
- Auth: `DOCTOR`
- Purpose: Return the doctor's availability and already booked times for one selected date.
- Query params: `date=YYYY-MM-DD`
- Example: `GET /api/doctor/available-times/day?date=2026-05-01` with `Authorization: Bearer {{doctorAccessToken}}`

### PUT `/api/doctor/available-times`
- Auth: `DOCTOR`
- Purpose: Update doctor availability for one day of the week using the signed-in doctor plus `dayOfWeek` in the request body.
- Example:
```json
{
  "dayOfWeek": 2,
  "from": "10:00",
  "to": "14:00",
  "isOn": true
}
```

### DELETE `/api/doctor/available-times/:id`
- Auth: `DOCTOR`
- Purpose: Delete doctor availability slot.
- Example: `DELETE /api/doctor/available-times/{{availableTimeId}}` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/doctor/status`
- Auth: `DOCTOR`
- Purpose: Return current doctor active status.
- Example: `GET /api/doctor/status` with `Authorization: Bearer {{doctorAccessToken}}`

### PUT `/api/doctor/status`
- Auth: `DOCTOR`
- Purpose: Update current doctor active status.
- Example:
```json
{
  "isActive": true
}
```

---

## 10. Patient Care and Medical Records

### GET `/api/care/patient/treatment-plans`
- Auth: `PATIENT`
- Purpose: Return treatment plans assigned to signed-in patient.
- Example: `GET /api/care/patient/treatment-plans` with `Authorization: Bearer {{patientAccessToken}}`

### GET `/api/care/patient/treatment-plans/latest`
- Auth: `PATIENT`
- Purpose: Return only the latest treatment plan assigned to the signed-in patient.
- Example: `GET /api/care/patient/treatment-plans/latest` with `Authorization: Bearer {{patientAccessToken}}`

### GET `/api/care/patient/treatment-plans/all`
- Auth: `PATIENT`
- Purpose: Return all treatment plans assigned to the signed-in patient.
- Example: `GET /api/care/patient/treatment-plans/all` with `Authorization: Bearer {{patientAccessToken}}`

### GET `/api/care/patient/history-record`
- Auth: `PATIENT`
- Purpose: Return latest medical history record for signed-in patient.
- Example: `GET /api/care/patient/history-record` with `Authorization: Bearer {{patientAccessToken}}`

### GET `/api/care/patient/history-record/latest`
- Auth: `PATIENT`
- Purpose: Return only the latest medical history record for signed-in patient.
- Example: `GET /api/care/patient/history-record/latest` with `Authorization: Bearer {{patientAccessToken}}`

### GET `/api/care/patient/history-records/all`
- Auth: `PATIENT`
- Purpose: Return all medical history records for signed-in patient.
- Example: `GET /api/care/patient/history-records/all` with `Authorization: Bearer {{patientAccessToken}}`

### POST `/api/care/patient/history-record`
- Auth: `PATIENT`
- Purpose: Create initial patient medical history record. Accepts JSON or `multipart/form-data`; when uploading images, send `record` as a JSON string and files under `images`.
- Example:
```json
{
  "record": {
    "diagnosis": "Stage II follow-up",
    "allergies": ["penicillin"]
  }
}
```
- Multipart example: `record={"diagnosis":"Stage II follow-up"}` with `images=@mri.png` and `images=@xray.jpg`

### POST `/api/care/patient/history-record/update-request`
- Auth: `PATIENT`
- Purpose: Create medical history update request for doctor approval. Accepts JSON or `multipart/form-data`; uploaded images are stored inside `record.images`.
- Example:
```json
{
  "doctorUserId": "cm_doctor_user_id",
  "record": {
    "symptoms": ["fatigue", "mild nausea"]
  }
}
```
- Multipart example: `doctorUserId=cm_doctor_user_id`, `record={"symptoms":["fatigue"]}` with `images=@scan-1.png`

---

## 11. Doctor Care and Medical Records

### GET `/api/care/doctor/patients/:patientUserId/treatment-plans`
- Auth: `DOCTOR`
- Purpose: Return treatment plans for one doctor-accessible patient. The route accepts either a linked patient `User.id` or a doctor-created `CreatedPatient.id`.
- Example: `GET /api/care/doctor/patients/{{patientId}}/treatment-plans` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/care/doctor/patients/:patientUserId/treatment-plans/latest`
- Auth: `DOCTOR`
- Purpose: Return only the latest treatment plan for one doctor-accessible patient.
- Example: `GET /api/care/doctor/patients/{{patientId}}/treatment-plans/latest` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/care/doctor/patients/:patientUserId/treatment-plans/all`
- Auth: `DOCTOR`
- Purpose: Return all treatment plans for one doctor-accessible patient.
- Example: `GET /api/care/doctor/patients/{{patientId}}/treatment-plans/all` with `Authorization: Bearer {{doctorAccessToken}}`

### POST `/api/care/doctor/patients/:patientUserId/treatment-plans`
- Auth: `DOCTOR`
- Purpose: Create treatment plan for one doctor-accessible patient using the patient id from the route. The route accepts either a linked patient `User.id` or a doctor-created `CreatedPatient.id`.
- Example:
```json
{
  "treatmentPlan": {
    "phase": "Cycle 1",
    "medications": ["drug-a"],
    "schedule": "Weekly"
  },
  "symptomsLog": {
    "pain": "mild"
  }
}
```

### POST `/api/care/doctor/treatment-plans`
- Auth: `DOCTOR`
- Purpose: Create treatment plan for a doctor-accessible patient using `patientId` or `patientUserId` in the request body.
- Example:
```json
{
  "patientId": "cm_patient_or_created_patient_id",
  "treatmentPlan": {
    "phase": "Cycle 1",
    "medications": ["drug-a"],
    "schedule": "Weekly"
  }
}
```

### PUT `/api/care/doctor/patients/:patientUserId/treatment-plans/:planId`
- Auth: `DOCTOR`
- Purpose: Update doctor's treatment plan for patient.
- Example:
```json
{
  "treatmentPlan": {
    "phase": "Cycle 2",
    "medications": ["drug-a", "drug-b"]
  }
}
```

### GET `/api/care/doctor/patients/:patientUserId/history-record`
- Auth: `DOCTOR`
- Purpose: Return latest medical history for a doctor-accessible patient. The route accepts either a linked patient `User.id` or a doctor-created `CreatedPatient.id`.
- Example: `GET /api/care/doctor/patients/{{patientId}}/history-record` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/care/doctor/patients/:patientUserId/history-record/latest`
- Auth: `DOCTOR`
- Purpose: Return only the latest medical history for a doctor-accessible patient.
- Example: `GET /api/care/doctor/patients/{{patientId}}/history-record/latest` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/care/doctor/patients/:patientUserId/history-records/all`
- Auth: `DOCTOR`
- Purpose: Return all medical history records for a doctor-accessible patient.
- Example: `GET /api/care/doctor/patients/{{patientId}}/history-records/all` with `Authorization: Bearer {{doctorAccessToken}}`

### POST `/api/care/doctor/patients/:patientUserId/history-record`
- Auth: `DOCTOR`
- Purpose: Create the initial medical history record for a doctor-accessible patient. The route accepts either a linked patient `User.id` or a doctor-created `CreatedPatient.id`. Accepts JSON or `multipart/form-data`; when uploading images, send `record` as a JSON string and files under `images`.
- Example:
```json
{
  "record": {
    "diagnosis": "Initial diagnosis",
    "allergies": ["penicillin"]
  }
}
```
- Multipart example: `record={"diagnosis":"Initial diagnosis"}` with `images=@mri.png`

### PUT `/api/care/doctor/patients/:patientUserId/history-record`
- Auth: `DOCTOR`
- Purpose: Create or update doctor-accessible patient medical history. The route accepts either a linked patient `User.id` or a doctor-created `CreatedPatient.id`. Accepts JSON or `multipart/form-data`; uploaded images are appended to `record.images`.
- Example:
```json
{
  "record": {
    "diagnosis": "Updated diagnosis after review"
  }
}
```
- Multipart example: `record={"diagnosis":"Updated diagnosis after review"}` with `images=@xray.jpg`

### PUT `/api/care/doctor/patients/:patientId`
- Auth: `DOCTOR`
- Purpose: Update a doctor-created patient from the care namespace. Full and partial payloads are both accepted.
- Example:
```json
{
  "fullName": "Updated Research Patient",
  "riskFactors": {
    "familyHistory": true
  }
}
```

### PATCH `/api/care/doctor/patients/:patientId`
- Auth: `DOCTOR`
- Purpose: Partially update a doctor-created patient from the care namespace.
- Example:
```json
{
  "medicalHistory": "Updated note"
}
```

### DELETE `/api/care/doctor/patients/:patientId`
- Auth: `DOCTOR`
- Purpose: Delete a doctor-created patient from the care namespace.
- Example: `DELETE /api/care/doctor/patients/{{patientId}}` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/care/doctor/history-update-requests`
- Auth: `DOCTOR`
- Purpose: Return patient-submitted history update requests.
- Example: `GET /api/care/doctor/history-update-requests` with `Authorization: Bearer {{doctorAccessToken}}`

### POST `/api/care/doctor/history-update-requests/:requestId/respond`
- Auth: `DOCTOR`
- Purpose: Approve or reject patient history update request.
- Example:
```json
{
  "action": "APPROVE"
}
```

---

## 12. AI Diagnosis and Resistance Workflows

### POST `/api/ai/cancer-diagnosis/start`
- Auth: Any authenticated role
- Purpose: Start Rasa-backed cancer diagnosis conversation.
- Example:
```json
{
  "sessionId": "session-123",
  "entryIntent": "/start_questions_and_image"
}
```

### POST `/api/ai/cancer-diagnosis/message`
- Auth: Any authenticated role
- Purpose: Send one diagnosis conversation message to the Rasa gateway.
- Example:
```json
{
  "sessionId": "session-123",
  "message": "/inform_free_text{\"dyspnea\":\"at_rest\"}"
}
```

### POST `/api/ai/cancer-diagnosis/image`
- Auth: Any authenticated role
- Purpose: Upload diagnosis image and forward its stored reference to Rasa using `/submit_image{...}`.
- Example: `multipart/form-data` with `image=@cxr.png` and optional `sessionId=session-123` (accepted field aliases: `image`, `file`, `upload`)

### POST `/api/ai/cancer-resistance/start`
- Auth: `PATIENT`
- Purpose: Start legacy cancer resistance conversation flow.
- Example:
```json
{
  "sessionId": "session-123",
  "entryIntent": "/start_cancer_resistance"
}
```

### POST `/api/ai/cancer-resistance/message`
- Auth: `PATIENT`
- Purpose: Send one legacy cancer resistance conversation message.
- Example:
```json
{
  "sessionId": "session-123",
  "message": "patient free text"
}
```

### POST `/api/ai/cancer-resistance/predict`
- Auth: `DOCTOR`
- Purpose: Doctor-only NSCLC prediction alias under the cancer-resistance namespace. Uses FastAPI NSCLC predictor and stores a prediction run.
- `patientId` accepts either:
  - active linked patient user id, or
  - doctor-created patient id (from doctor patient lists).
- Example:
```json
{
  "patientId": "cm_patient_user_id_here",
  "includeLlmExplanation": false,
  "overrides": {
    "smoking_status_group": "Former smoker",
    "stage_dx": "Stage IV"
  }
}
```

### GET `/api/ai/cancer-resistance/last-result/:patientId`
- Auth: `DOCTOR`
- Purpose: Return the latest successful stored NSCLC result for a doctor-accessible patient id (normal or created).
- Example: `GET /api/ai/cancer-resistance/last-result/{{patientId}}` with `Authorization: Bearer {{doctorAccessToken}}`

### POST `/api/ai/nsclc/predict`
- Auth: `DOCTOR`
- Purpose: Primary NSCLC FastAPI prediction endpoint for early failure risk, durable benefit likelihood, and resistance interpretation.
- `patientId` accepts either:
  - active linked patient user id, or
  - doctor-created patient id (from doctor patient lists).
- Example:
```json
{
  "patientId": "cm_patient_user_id_here",
  "includeLlmExplanation": false,
  "overrides": {
    "smoking_status_group": "Former smoker",
    "stage_dx": "Stage IV"
  }
}
```

### GET `/api/ai/nsclc/last-result/:patientId`
- Auth: `DOCTOR`
- Purpose: Return the latest successful stored NSCLC result for a doctor-accessible patient id (normal or created).
- Example: `GET /api/ai/nsclc/last-result/{{patientId}}` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/ai/genomic-target-prioritization/health`
- Auth: `DOCTOR`
- Purpose: Report whether the genomic target prioritization FastAPI service (`AI_SERVICE_URL`) is reachable and has its pipeline artifacts loaded.
- Example: `GET /api/ai/genomic-target-prioritization/health` with `Authorization: Bearer {{doctorAccessToken}}`

### POST `/api/ai/genomic-target-prioritization/analyze`
- Auth: `DOCTOR`
- Content type: `multipart/form-data`
- Purpose: Rank candidate genomic targets in lung cancer, assign evidence tiers and safety context, match external NCG/CIViC evidence, and return the research-use report with stored model-evaluation metrics.
- Fields:
  - `topN` (optional, `1`–`100`, default `20`): number of ranked targets to return.
  - `mutationsFile` (optional, CSV): gene-level mutation table.
  - `expressionFile` (optional, CSV): gene x sample RNA expression matrix.
- Upload both files to run the pipeline over your data, or send neither to report the pre-computed reference cohort. Sending only one file returns `400`.
- Example: `POST /api/ai/genomic-target-prioritization/analyze` with form fields `topN=20`, `mutationsFile=@mutations.csv`, `expressionFile=@expression.csv`

### GET `/api/ai/genomic-target-prioritization/results/:runId`
- Auth: `DOCTOR`
- Purpose: Replay a stored analysis payload using the `runId` returned by `analyze`.
- Example: `GET /api/ai/genomic-target-prioritization/results/{{runId}}` with `Authorization: Bearer {{doctorAccessToken}}`

### GET `/api/ai/genomic-target-prioritization/results/:runId/report`
- Auth: `DOCTOR`
- Purpose: Return the generated Markdown research report for one run (`text/markdown`).
- Example: `GET /api/ai/genomic-target-prioritization/results/{{runId}}/report` with `Authorization: Bearer {{doctorAccessToken}}`

---

## 13. Psychological Support and Knowledge Workflows

### POST `/api/patient/psychological-support/grace-link`
- Auth: `PATIENT`
- Purpose: Create or refresh the Grace patient link and return a deep-link URL for the psychological-support service.
- Example: `POST /api/patient/psychological-support/grace-link` with `Authorization: Bearer {{patientAccessToken}}`

### POST `/api/patient/psychological-support/chat`
- Auth: `PATIENT`
- Purpose: Send patient message to Grace/Liora and return the reply with persistent `session_id`.
- Example:
```json
{
  "message": "I feel overwhelmed today."
}
```

### GET `/api/patient/psychological-support/chat/session`
- Auth: `PATIENT`
- Purpose: Return current psychological chat session metadata for continuity.
- Example: `GET /api/patient/psychological-support/chat/session` with `Authorization: Bearer {{patientAccessToken}}`

### POST `/api/patient/psychological-support/exercises/complete`
- Auth: `PATIENT`
- Purpose: Save completion metadata for a relaxation exercise session.
- Example:
```json
{
  "exercise_type": "box_breathing",
  "duration_minutes": 3
}
```

### GET `/api/patient/psychological-support/articles`
- Auth: `PATIENT`
- Purpose: List published educational knowledge articles for the psychological-support module.
- Query params: `category=cancer|wellbeing|curevoo`, `language=en|ar`
- Example: `GET /api/patient/psychological-support/articles?category=cancer` with `Authorization: Bearer {{patientAccessToken}}`

### GET `/api/patient/psychological-support/articles/:id`
- Auth: `PATIENT`
- Purpose: Return full article details by id.
- Example: `GET /api/patient/psychological-support/articles/{{articleId}}` with `Authorization: Bearer {{patientAccessToken}}`

### POST `/api/patient/psychological-support/search`
- Auth: `PATIENT`
- Purpose: Run educational-only cancer search with safety filtering and refusal logic for diagnosis/treatment/medication prompts.
- Example:
```json
{
  "question": "What is EGFR targeted therapy?"
}
```

### GET `/api/admin/knowledge-articles`
- Auth: `ADMIN`
- Purpose: List all knowledge articles (published and unpublished).
- Query params: `category=cancer|wellbeing|curevoo`, `language=en|ar`
- Example: `GET /api/admin/knowledge-articles?category=cancer` with `Authorization: Bearer {{adminAccessToken}}`

### GET `/api/admin/knowledge-articles/:id`
- Auth: `ADMIN`
- Purpose: Return full knowledge article details by id (includes content).
- Example: `GET /api/admin/knowledge-articles/{{articleId}}` with `Authorization: Bearer {{adminAccessToken}}`

### GET `/api/admin/knowledge-articles/:id/metadata`
- Auth: `ADMIN`
- Purpose: Return article metadata by id (excludes `content` body).
- Example: `GET /api/admin/knowledge-articles/{{articleId}}/metadata` with `Authorization: Bearer {{adminAccessToken}}`

### POST `/api/admin/knowledge-articles`
- Auth: `ADMIN`
- Purpose: Create a knowledge article entry for psychological-support education pages.
- Example:
```json
{
  "title": "What is NSCLC?",
  "category": "cancer",
  "summary": "Simple explanation for patients.",
  "content": "NSCLC is ...",
  "sources": [
    {
      "title": "National Cancer Institute",
      "url": "https://www.cancer.gov/"
    }
  ],
  "language": "en",
  "is_published": true
}
```

### PUT `/api/admin/knowledge-articles/:id`
- Auth: `ADMIN`
- Purpose: Update an existing knowledge article.
- Example:
```json
{
  "summary": "Updated summary text"
}
```

### DELETE `/api/admin/knowledge-articles/:id`
- Auth: `ADMIN`
- Purpose: Delete one knowledge article by id.
- Example: `DELETE /api/admin/knowledge-articles/{{articleId}}` with `Authorization: Bearer {{adminAccessToken}}`

---

## Notes

- This file reflects the active route mounts in `src/app.js`.
- The following older routes are intentionally not listed because they are not currently mounted:
  - `POST /api/patients/test-records`
  - `GET /api/patients/ai-results`
