# QuickPeek Source Expansion Plan

This is a release-minded shortlist of source additions that fit QuickPeek's current architecture well.

## Best Next Public Sources

### 1. Hacker News
- Why it fits: Official public API, no auth, simple JSON, no rate limit called out in the official docs.
- Good metrics:
  - user karma
  - submitted item count
  - story score
  - story comment count
- Official source:
  - https://github.com/HackerNews/API
- Effort: low
- Risk: low

### 2. Stack Overflow / Stack Exchange
- Why it fits: Official API, strong creator/dev audience overlap, clean numeric metrics.
- Good metrics:
  - user reputation
  - question score
  - answer score
  - answer count
- Official source:
  - https://api.stackexchange.com/docs/users-by-ids
  - https://api.stackexchange.com/docs/questions-on-users
- Effort: medium
- Risk: low to medium
- Note: user lookup is a little trickier because names are not stable IDs.

### 3. Mastodon
- Why it fits: Public account stats are exposed by instance APIs.
- Good metrics:
  - followers
  - following
  - statuses/posts
- Official source:
  - https://docs.joinmastodon.org/methods/accounts/
  - https://docs.joinmastodon.org/entities/Account/
- Effort: medium
- Risk: medium
- Note: handle resolution across instances is the main complexity, not the metric fetch itself.

### 4. Docker Hub
- Why it fits: Strong audience overlap for open-source projects and developer products.
- Good metrics:
  - pull count
  - star count
  - repo count for an org
- Official source:
  - https://docs.docker.com/docker-hub/
  - https://docs.docker.com/docker-hub/repos/manage/export/
- Effort: medium
- Risk: medium
- Note: docs clearly reference Docker Hub API usage, but we should verify the exact public endpoint contract before shipping.

### 5. DEV / Forem
- Why it fits: Useful for creator/dev audience and publishing workflows.
- Good metrics:
  - follower count
  - published article count
- Official source:
  - https://developers.forem.com/api/
  - https://developers.forem.com/api/v1
- Effort: medium
- Risk: medium
- Note: follower endpoints in the official docs are authenticated, so this may land better as an account-linked source than as a public one.

## Worth Adding With Login

### Bluesky authenticated account metrics
- Good metrics:
  - unread notifications
- Official source:
  - https://docs.bsky.app/docs/api/app-bsky-notification-get-unread-count
- Effort: medium
- Risk: medium
- Product note: good second-stage feature after public Bluesky tracking.

## Sources I Would Avoid For Now

### Google Analytics / YouTube Studio style private dashboards
- Reason: high trust surface, more sensitive scopes, and users will judge reliability harshly.

### Instagram private/account-only metrics
- Reason: scraping is fragile and policy risk is higher than the upside.

### X authenticated creator metrics
- Reason: access cost and policy volatility make it a poor trust-first addition right now.

## Recommended Order

1. Hacker News
2. Stack Overflow
3. Mastodon
4. Docker Hub, if public endpoint stability checks out

## Product Guidance

- Keep public sources public-first: if official public APIs exist, prefer them over scraping.
- For login-based sources, group them under a separate "Connected Accounts" mental model in the UI.
- Do not mix fragile scraping-based private metrics into the same trust tier as official API-backed sources.
