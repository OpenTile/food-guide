create table entries (
    id uuid primary key,
    text text not null,
    eaten_at timestamptz not null
);

-- Every read filters on a range of Eaten At.
create index entries_eaten_at_idx on entries (eaten_at);
