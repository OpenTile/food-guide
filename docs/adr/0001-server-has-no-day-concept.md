# The server has no concept of a day

"Today" is a local notion, but stored instants are global, and the one thing this system does is
show you a day. We put the day boundary entirely in the client: it computes the Day Window from
the device's current timezone and asks for a range of instants, so the server stores and queries
instants only and contains no timezone code at all.

## Consequences

- There is deliberately **no** `/entries/today` endpoint, and there should not be one. A future
  reader will find that omission surprising and should resist adding it — it would move the day
  boundary onto the server and reintroduce the timezone problem this decision removes.
- Adding history navigation, or any other date range, requires no server change whatsoever.
- Entries re-bucket across days if the user changes timezone, because the Day Window is computed
  fresh from the current timezone rather than pinned at write time. Accepted: correct for the
  common case, and the alternative costs a second field that must be kept consistent forever.
