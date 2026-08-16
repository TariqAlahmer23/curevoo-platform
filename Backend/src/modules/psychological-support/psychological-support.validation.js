// Defines request validation schemas for psychological support endpoints.
const { z } = require("zod");

const chatMessageSchema = z.object({
  message: z.string().trim().min(1).max(4000),
  session_id: z.string().trim().min(1).max(200).optional(),
});

const exerciseTypeSchema = z.enum([
  "box_breathing",
  "progressive_muscle_relaxation",
]);

const exerciseCompleteSchema = z.object({
  exercise_type: exerciseTypeSchema,
  duration_minutes: z.number().int().min(1).max(120).optional(),
});

const listArticlesQuerySchema = z.object({
  category: z.enum(["cancer", "wellbeing", "curevoo"]).optional(),
  language: z.string().trim().min(2).max(10).optional(),
});

const searchQuestionSchema = z.object({
  question: z.string().trim().min(3).max(4000),
});

const sourceItemSchema = z.object({
  title: z.string().trim().min(1).max(300),
  url: z.string().trim().url(),
});

const knowledgeArticleCreateSchema = z.object({
  title: z.string().trim().min(2).max(300),
  slug: z.string().trim().min(2).max(300).optional(),
  category: z.enum(["cancer", "wellbeing", "curevoo"]),
  summary: z.string().trim().min(10).max(3000),
  content: z.string().trim().min(20).max(50000),
  sources: z.array(sourceItemSchema).min(1).max(20).optional(),
  language: z.string().trim().min(2).max(10).optional(),
  reading_time_minutes: z.number().int().min(1).max(120).optional(),
  is_published: z.boolean().optional(),
});

const knowledgeArticleUpdateSchema = z.object({
  title: z.string().trim().min(2).max(300).optional(),
  slug: z.string().trim().min(2).max(300).optional(),
  category: z.enum(["cancer", "wellbeing", "curevoo"]).optional(),
  summary: z.string().trim().min(10).max(3000).optional(),
  content: z.string().trim().min(20).max(50000).optional(),
  sources: z.array(sourceItemSchema).min(1).max(20).optional(),
  language: z.string().trim().min(2).max(10).optional(),
  reading_time_minutes: z.number().int().min(1).max(120).optional(),
  is_published: z.boolean().optional(),
});

module.exports = {
  chatMessageSchema,
  exerciseCompleteSchema,
  exerciseTypeSchema,
  knowledgeArticleCreateSchema,
  knowledgeArticleUpdateSchema,
  listArticlesQuerySchema,
  searchQuestionSchema,
};
