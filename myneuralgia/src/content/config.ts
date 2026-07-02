import { defineCollection, z } from 'astro:content';

const articles = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    slug: z.string(),
    date: z.string(),
    status: z.enum(['draft', 'published']).default('draft'),
    meta_title: z.string().optional(),
    meta_description: z.string().optional(),
    tags: z.array(z.string()).optional(),
    source_ref: z.string().optional(),
    translated_at: z.string().optional(),
    translated_by: z.string().optional(),
    translation_origin: z.enum(['ai', 'manual']).optional(),
  }),
});

export const collections = { articles };
