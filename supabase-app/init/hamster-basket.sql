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

-- 5. Enable realtime for both tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.todo_lists;
ALTER PUBLICATION supabase_realtime ADD TABLE public.todos;
