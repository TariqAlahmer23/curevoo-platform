// Handles appointment persistence, doctor lookups, and scheduling conflict queries.
const { prisma } = require("../../prisma/client");

function selectAppointmentFields(options = {}) {
  const {
    includeDoctor = false,
    includePatient = false,
    includeCreatedPatient = false,
  } = options;
  const select = {
    id: true,
    patientUserId: true,
    createdPatientId: true,
    doctorUserId: true,
    scheduledAt: true,
    appointmentEnd: true,
    reason: true,
    notes: true,
    status: true,
    canceledAt: true,
    createdAt: true,
    updatedAt: true,
  };

  if (includeDoctor) {
    select.doctor = {
      select: {
        id: true,
        email: true,
        doctorProfile: { select: { fullName: true, specialization: true } },
      },
    };
  }

  if (includePatient) {
    select.patient = {
      select: {
        id: true,
        email: true,
        name: true,
        phoneNumber: true,
        patientProfile: { select: { fullName: true } },
      },
    };
  }

  if (includeCreatedPatient) {
    select.createdPatient = {
      select: {
        id: true,
        sourcePatientUserId: true,
        fullName: true,
        phoneNumber: true,
      },
    };
  }

  return select;
}

function selectBookedSlotFields() {
  return {
    id: true,
    patientUserId: true,
    createdPatientId: true,
    doctorUserId: true,
    scheduledAt: true,
    reason: true,
    status: true,
    patient: {
      select: {
        id: true,
        name: true,
        patientProfile: {
          select: {
            fullName: true,
          },
        },
      },
    },
    createdPatient: {
      select: {
        id: true,
        fullName: true,
      },
    },
  };
}

// Executes the database operation for "find doctor user by id".
function findDoctorUserById(id) {
  return prisma.user.findUnique({
    where: { id },
    select: {
      id: true,
      role: true,
      doctorProfile: { select: { id: true, isActive: true, fullName: true } },
    },
  });
}

// Executes the database operation for "get doctor availability by user id".
function getDoctorAvailabilityByUserId(doctorUserId) {
  return prisma.doctorProfile.findFirst({
    where: { userId: doctorUserId, isActive: true },
    select: {
      id: true,
      availableTimes: {
        select: {
          id: true,
          dayOfWeek: true,
          startTime: true,
          endTime: true,
          isOn: true,
        },
        orderBy: [{ dayOfWeek: "asc" }, { startTime: "asc" }],
      },
    },
  });
}

// Executes the database operation for "create appointment".
function createAppointment(data) {
  return prisma.appointment.create({
    data,
    select: selectAppointmentFields({
      includeDoctor: true,
      includePatient: true,
      includeCreatedPatient: true,
    }),
  });
}

// Executes the database operation for "list patient appointments".
function listPatientAppointments(patientUserId) {
  return prisma.appointment.findMany({
    where: { patientUserId },
    orderBy: { createdAt: "desc" },
    select: selectAppointmentFields({ includeDoctor: true }),
  });
}

// Executes the database operation for "find appointment by id".
function findAppointmentById(id) {
  return prisma.appointment.findUnique({
    where: { id },
  });
}

// Executes the database operation for "find doctor appointment conflict".
function findDoctorAppointmentConflict(doctorUserId, scheduledAt) {
  return prisma.appointment.findFirst({
    where: {
      doctorUserId,
      scheduledAt,
      status: { in: ["PENDING", "CREATED", "CONFIRMED"] },
    },
    select: { id: true },
  });
}

// Executes the database operation for "list doctor appointments".
function listDoctorAppointments(doctorUserId, status = null) {
  const where = { doctorUserId };
  if (status) where.status = status;
  return prisma.appointment.findMany({
    where,
    orderBy: { createdAt: "desc" },
    select: selectAppointmentFields({
      includePatient: true,
      includeCreatedPatient: true,
    }),
  });
}

// Executes the database operation for "list upcoming doctor appointments".
function listUpcomingDoctorAppointments(doctorUserId) {
  return prisma.appointment.findMany({
    where: {
      doctorUserId,
      status: { in: ["PENDING", "CREATED", "CONFIRMED"] },
      scheduledAt: {
        gt: new Date(),
      },
    },
    orderBy: [{ scheduledAt: "asc" }, { createdAt: "asc" }],
    select: selectAppointmentFields({
      includePatient: true,
      includeCreatedPatient: true,
    }),
  });
}

// Executes the database operation for "list booked appointment slots for a doctor".
function listBookedAppointmentsByDoctorUserId(doctorUserId, startDate, endDate) {
  return prisma.appointment.findMany({
    where: {
      doctorUserId,
      status: { in: ["PENDING", "CREATED", "CONFIRMED"] },
      scheduledAt: {
        gte: startDate,
        lt: endDate,
      },
    },
    orderBy: { scheduledAt: "asc" },
    select: selectBookedSlotFields(),
  });
}

// Executes the database operation for "find doctor-accessible appointment subject".
async function findDoctorAppointmentSubject(doctorUserId, patientId) {
  // First, try a real linked patient by User.id.
  const link = await prisma.doctorPatientLink.findFirst({
    where: {
      doctorUserId,
      patientUserId: patientId,
      status: "ACTIVE",
    },
    select: {
      patient: {
        select: {
          id: true,
          email: true,
          name: true,
          phoneNumber: true,
          patientProfile: {
            select: {
              fullName: true,
            },
          },
        },
      },
    },
  });

  if (link?.patient) {
    return {
      patientType: "NORMAL",
      patientUserId: link.patient.id,
      createdPatientId: null,
      patient: link.patient,
      createdPatient: null,
    };
  }

  // If no active link exists, try doctor-created patient by CreatedPatient.id.
  const createdPatient = await prisma.createdPatient.findFirst({
    where: {
      id: patientId,
      doctorUserId,
    },
    select: {
      id: true,
      sourcePatientUserId: true,
      fullName: true,
      phoneNumber: true,
    },
  });

  if (!createdPatient) return null;

  return {
    patientType: "CREATED",
    patientUserId: null,
    createdPatientId: createdPatient.id,
    patient: null,
    createdPatient,
  };
}

// Executes the database operation for "find one booked appointment slot by id for doctor".
function findBookedAppointmentByIdForDoctor(doctorUserId, appointmentId) {
  return prisma.appointment.findFirst({
    where: {
      id: appointmentId,
      doctorUserId,
      status: { in: ["PENDING", "CREATED", "CONFIRMED"] },
    },
    select: selectBookedSlotFields(),
  });
}

// Executes the database operation for "update appointment by id".
function updateAppointmentById(id, data) {
  return prisma.appointment.update({
    where: { id },
    data,
    select: selectAppointmentFields({
      includePatient: true,
      includeCreatedPatient: true,
    }),
  });
}

// Executes the database operation for "delete appointment by id".
function deleteAppointmentById(id) {
  return prisma.appointment.delete({
    where: { id },
    select: { id: true },
  });
}

module.exports = {
  findDoctorUserById,
  getDoctorAvailabilityByUserId,
  createAppointment,
  listPatientAppointments,
  findAppointmentById,
  findDoctorAppointmentConflict,
  listDoctorAppointments,
  listUpcomingDoctorAppointments,
  listBookedAppointmentsByDoctorUserId,
  findBookedAppointmentByIdForDoctor,
  findDoctorAppointmentSubject,
  updateAppointmentById,
  deleteAppointmentById,
};
