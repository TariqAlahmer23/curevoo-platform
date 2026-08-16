-- CreateEnum
CREATE TYPE "PsychologicalChatSender" AS ENUM ('PATIENT', 'LIORA');

-- CreateEnum
CREATE TYPE "PsychologicalExerciseType" AS ENUM ('BOX_BREATHING', 'PROGRESSIVE_MUSCLE_RELAXATION');

-- CreateEnum
CREATE TYPE "KnowledgeArticleCategory" AS ENUM ('CANCER', 'WELLBEING', 'CUREVOO');

-- CreateEnum
CREATE TYPE "EducationalSearchSafetyStatus" AS ENUM ('ALLOWED', 'BLOCKED', 'CRISIS');

-- CreateTable
CREATE TABLE "psychological_chat_sessions" (
    "id" TEXT NOT NULL,
    "patient_id" TEXT NOT NULL,
    "grace_patient_id" TEXT,
    "session_id" TEXT,
    "redirect_url" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "psychological_chat_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "psychological_chat_messages" (
    "id" TEXT NOT NULL,
    "patient_id" TEXT NOT NULL,
    "chat_session_id" TEXT,
    "session_id" TEXT,
    "sender" "PsychologicalChatSender" NOT NULL,
    "message" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "psychological_chat_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "psychological_exercise_logs" (
    "id" TEXT NOT NULL,
    "patient_id" TEXT NOT NULL,
    "exercise_type" "PsychologicalExerciseType" NOT NULL,
    "duration_minutes" INTEGER,
    "completed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "psychological_exercise_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "knowledge_articles" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "category" "KnowledgeArticleCategory" NOT NULL,
    "summary" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "sources" JSONB,
    "language" TEXT NOT NULL DEFAULT 'en',
    "reading_time_minutes" INTEGER,
    "is_published" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "knowledge_articles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "educational_search_logs" (
    "id" TEXT NOT NULL,
    "patient_id" TEXT NOT NULL,
    "question" TEXT NOT NULL,
    "answer_summary" TEXT,
    "safety_status" "EducationalSearchSafetyStatus" NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "educational_search_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "psychological_chat_sessions_patient_id_key" ON "psychological_chat_sessions"("patient_id");

-- CreateIndex
CREATE INDEX "psychological_chat_sessions_patient_id_updated_at_idx" ON "psychological_chat_sessions"("patient_id", "updated_at");

-- CreateIndex
CREATE INDEX "psychological_chat_messages_patient_id_created_at_idx" ON "psychological_chat_messages"("patient_id", "created_at");

-- CreateIndex
CREATE INDEX "psychological_chat_messages_session_id_created_at_idx" ON "psychological_chat_messages"("session_id", "created_at");

-- CreateIndex
CREATE INDEX "psychological_chat_messages_chat_session_id_created_at_idx" ON "psychological_chat_messages"("chat_session_id", "created_at");

-- CreateIndex
CREATE INDEX "psychological_exercise_logs_patient_id_completed_at_idx" ON "psychological_exercise_logs"("patient_id", "completed_at");

-- CreateIndex
CREATE INDEX "psychological_exercise_logs_exercise_type_completed_at_idx" ON "psychological_exercise_logs"("exercise_type", "completed_at");

-- CreateIndex
CREATE UNIQUE INDEX "knowledge_articles_slug_key" ON "knowledge_articles"("slug");

-- CreateIndex
CREATE INDEX "knowledge_articles_category_language_is_published_idx" ON "knowledge_articles"("category", "language", "is_published");

-- CreateIndex
CREATE INDEX "knowledge_articles_language_is_published_created_at_idx" ON "knowledge_articles"("language", "is_published", "created_at");

-- CreateIndex
CREATE INDEX "educational_search_logs_patient_id_created_at_idx" ON "educational_search_logs"("patient_id", "created_at");

-- CreateIndex
CREATE INDEX "educational_search_logs_safety_status_created_at_idx" ON "educational_search_logs"("safety_status", "created_at");

-- AddForeignKey
ALTER TABLE "psychological_chat_sessions" ADD CONSTRAINT "psychological_chat_sessions_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "psychological_chat_messages" ADD CONSTRAINT "psychological_chat_messages_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "psychological_chat_messages" ADD CONSTRAINT "psychological_chat_messages_chat_session_id_fkey" FOREIGN KEY ("chat_session_id") REFERENCES "psychological_chat_sessions"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "psychological_exercise_logs" ADD CONSTRAINT "psychological_exercise_logs_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "educational_search_logs" ADD CONSTRAINT "educational_search_logs_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
