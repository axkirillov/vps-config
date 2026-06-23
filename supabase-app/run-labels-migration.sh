#!/bin/bash
# Run labels migration on the live Supabase DB
set -euo pipefail

SQL=$(cat <<'EOF'
-- labels table
CREATE TABLE IF NOT EXISTS public.labels (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    name TEXT NOT NULL,
    color TEXT DEFAULT '#3B82F6',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- todo_labels junction table
CREATE TABLE IF NOT EXISTS public.todo_labels (
    todo_id INTEGER NOT NULL REFERENCES public.todos(id) ON DELETE CASCADE,
    label_id INTEGER NOT NULL REFERENCES public.labels(id) ON DELETE CASCADE,
    PRIMARY KEY (todo_id, label_id)
);

-- RLS: labels
ALTER TABLE public.labels ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "Users select own labels" ON public.labels FOR SELECT USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    CREATE POLICY "Users insert own labels" ON public.labels FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    CREATE POLICY "Users update own labels" ON public.labels FOR UPDATE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    CREATE POLICY "Users delete own labels" ON public.labels FOR DELETE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- RLS: todo_labels
ALTER TABLE public.todo_labels ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
    CREATE POLICY "Users select own todo_labels" ON public.todo_labels
        FOR SELECT USING (
            EXISTS (SELECT 1 FROM public.todos WHERE todos.id = todo_labels.todo_id AND todos.user_id = auth.uid())
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    CREATE POLICY "Users insert own todo_labels" ON public.todo_labels
        FOR INSERT WITH CHECK (
            EXISTS (SELECT 1 FROM public.todos WHERE todos.id = todo_labels.todo_id AND todos.user_id = auth.uid())
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    CREATE POLICY "Users delete own todo_labels" ON public.todo_labels
        FOR DELETE USING (
            EXISTS (SELECT 1 FROM public.todos WHERE todos.id = todo_labels.todo_id AND todos.user_id = auth.uid())
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Enable realtime for new tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.labels;
ALTER PUBLICATION supabase_realtime ADD TABLE public.todo_labels;
EOF
)

echo "Running labels migration on supabase-db container..."
echo "$SQL" | docker exec -i supabase-db psql -U postgres
echo "Done!"
