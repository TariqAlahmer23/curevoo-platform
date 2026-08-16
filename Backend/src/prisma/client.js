// Exposes a shared Prisma client instance for the whole application.
const { PrismaClient } = require("@prisma/client");

const prisma = new PrismaClient();

// Support both import styles used in the codebase:
// const prisma = require("../../prisma/client")
// const { prisma } = require("../../prisma/client")
module.exports = prisma;
module.exports.prisma = prisma;
