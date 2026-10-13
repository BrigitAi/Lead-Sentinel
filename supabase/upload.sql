-- =====================================================================
-- Brigit Trivia League — let approvers add questions (upload from Excel/CSV)
-- Run once in the Supabase SQL editor. Safe to re-run.
-- =====================================================================
drop policy if exists "questions approver insert" on public.quiz_questions;
create policy "questions approver insert" on public.quiz_questions for insert to authenticated
  with check (public.quiz_is_approver());
