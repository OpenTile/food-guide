export type Entry = {
  id: string;
  text: string;
  eatenAt: Date;
};

export type EntryRange = {
  from: Date;
  to: Date;
};

export type CreateEntryResult = {
  /** The stored Entry; an identifier conflict returns the Entry already in storage. */
  entry: Entry;
  /** Whether this call inserted the Entry rather than finding its identifier already stored. */
  inserted: boolean;
};

/** Stores Entries and retrieves them by a half-open range of Eaten At instants. */
export interface EntryStore {
  /** Stores an Entry, succeeding idempotently when its identifier already exists. */
  create(entry: Entry): Promise<CreateEntryResult>;
  /** Returns Entries with Eaten At in `[from, to)`, ordered by Eaten At then identifier ascending. */
  list(range: EntryRange): Promise<Entry[]>;
}
