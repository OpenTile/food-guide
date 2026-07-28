# Food Guide

A personal food log. One person records what they ate as free text and reads back what they
recorded for the current day. The system stores what it is told and interprets none of it.

## Language

**Entry**:
A single free-text record of one eating occasion, belonging to the one user of the system.
Its text is stored verbatim and is never parsed, categorised, or scored.
_Avoid_: meal, item, record, log entry, diary entry

**Eating Occasion**:
One continuous act of eating, regardless of how many foods it involved. Two eggs, toast
and coffee eaten together are one eating occasion, and therefore one [[Entry]].
_Avoid_: meal, sitting, course

**Eaten At**:
The instant an eating occasion happened. Distinct from the moment the Entry reached storage,
which the system does not record.
_Avoid_: created at, logged at, timestamp

**Day Window**:
The half-open range of instants that makes up one calendar day in the user's current local
timezone. Entries are always retrieved by Day Window; the system has no notion of a
calendar date on its own.
_Avoid_: today, date, day

**Draft**:
Text the user has typed but not yet committed as an Entry. A Draft that fails to save
remains a Draft.
_Avoid_: pending entry, unsaved entry, new entry
