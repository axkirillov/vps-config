-- Hamster Basket app schema
-- Tables: todo_lists, todos with RLS policies

-- 1. todo_lists
CREATE TABLE IF NOT EXISTS public.todo_lists (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. todos
CREATE TABLE IF NOT EXISTS public.todos (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    task TEXT NOT NULL,
    is_complete BOOLEAN DEFAULT FALSE,
    list_id INTEGER REFERENCES public.todo_lists(id) ON DELETE CASCADE,
    inserted_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Enable RLS
ALTER TABLE public.todo_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.todos ENABLE ROW LEVEL SECURITY;

-- 4. RLS policies — users can only access their own data
-- todo_lists: select own lists
CREATE POLICY "Users select own lists" ON public.todo_lists
    FOR SELECT
    USING (auth.uid() = user_id);

-- todo_lists: insert own lists
CREATE POLICY "Users insert own lists" ON public.todo_lists
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- todo_lists: update own lists
CREATE POLICY "Users update own lists" ON public.todo_lists
    FOR UPDATE
    USING (auth.uid() = user_id);

-- todo_lists: delete own lists
CREATE POLICY "Users delete own lists" ON public.todo_lists
    FOR DELETE
    USING (auth.uid() = user_id);

-- todos: select own todos
CREATE POLICY "Users select own todos" ON public.todos
    FOR SELECT
    USING (auth.uid() = user_id);

-- todos: insert own todos
CREATE POLICY "Users insert own todos" ON public.todos
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- todos: update own todos
CREATE POLICY "Users update own todos" ON public.todos
    FOR UPDATE
    USING (auth.uid() = user_id);

-- todos: delete own todos
CREATE POLICY "Users delete own todos" ON public.todos
    FOR DELETE
    USING (auth.uid() = user_id);

-- 5. labels
CREATE TABLE IF NOT EXISTS public.labels (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL,
    name TEXT NOT NULL,
    color TEXT DEFAULT '#3B82F6',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. todo_labels (junction)
CREATE TABLE IF NOT EXISTS public.todo_labels (
    todo_id INTEGER NOT NULL REFERENCES public.todos(id) ON DELETE CASCADE,
    label_id INTEGER NOT NULL REFERENCES public.labels(id) ON DELETE CASCADE,
    PRIMARY KEY (todo_id, label_id)
);

-- RLS: labels
ALTER TABLE public.labels ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users select own labels" ON public.labels FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own labels" ON public.labels FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own labels" ON public.labels FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own labels" ON public.labels FOR DELETE USING (auth.uid() = user_id);

-- RLS: todo_labels
ALTER TABLE public.todo_labels ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users select own todo_labels" ON public.todo_labels
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.todos WHERE todos.id = todo_labels.todo_id AND todos.user_id = auth.uid())
    );
CREATE POLICY "Users insert own todo_labels" ON public.todo_labels
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM public.todos WHERE todos.id = todo_labels.todo_id AND todos.user_id = auth.uid())
    );
CREATE POLICY "Users delete own todo_labels" ON public.todo_labels
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM public.todos WHERE todos.id = todo_labels.todo_id AND todos.user_id = auth.uid())
    );

-- 7. Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.todo_lists;
ALTER PUBLICATION supabase_realtime ADD TABLE public.todos;
ALTER PUBLICATION supabase_realtime ADD TABLE public.labels;
ALTER PUBLICATION supabase_realtime ADD TABLE public.todo_labels;
