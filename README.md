# discourse-mail-daily-summary

Fork of [discourse-mlm-daily-summary](https://github.com/procourse/discourse-mlm-daily-summary) with extended scheduling, per-user frequency overrides, category scoping, and unsubscribe handling.

## What This Plugin Does

This plugin adds a periodic "Activity Update" email to Discourse.

- Sends activity updates as `daily` or `weekly` emails.
- Supports a site-wide default frequency and per-user frequency override.
- Can send at a configured time (`HH:MM`) each day.
- Can restrict included topics to configured categories (including direct subcategories).
- Can auto-enable emails for members of selected groups.
- Supports opt-in or opt-out default behavior.
- Adds an unsubscribe flow and optional unsubscribe link in the email.
- Can optionally use this email type for the admin digest preview/send endpoints.

## How Delivery Works

- A scheduled job runs every 5 minutes in production.
- If `mail_daily_summary_at` is set, enqueuing starts only after that time each day.
- Daily users are enqueued every day.
- Weekly users are enqueued only on `mail_daily_summary_day_of_week` (`0 = Sunday`).
- Users are throttled by per-user send tracking (`user_mail_summary_last_sent_at`):
  - daily: not sent again within 1 day
  - weekly: not sent again within 7 days

Email content includes topics with posts newer than the selected window:

- daily: posts from the last 24 hours
- weekly: posts from the last 7 days

## User Selection Rules

Base user scope includes real, activated, approved (or staff), non-staged, non-suspended, non-silenced users older than ~24h.

Subscription behavior:

- If `mail_daily_summary_enable_as_default = false`: users must explicitly enable it.
- If `mail_daily_summary_enable_as_default = true`: users receive it unless they explicitly disable it.

Frequency behavior:

- Site default is set by `mail_daily_summary_frequency`.
- Users can override with `user_mail_summary_frequency` (`daily` or `weekly`).
- If a user chooses "Site Default" in preferences, no explicit override is stored.

## Site Settings

- `mail_daily_summary_enabled`
- `mail_daily_summary_enable_as_default`
- `mail_daily_summary_at`
- `mail_daily_summary_last_run_at` (currently not used by enqueue/content window logic)
- `mail_daily_summary_debug_mode`
- `mail_daily_summary_add_unsubscribe_link`
- `mail_daily_summary_auto_enabled_groups`
- `mail_daily_summary_enabled_categories`
- `mail_daily_summary_frequency`
- `mail_daily_summary_day_of_week`
- `mail_daily_summary_max_posts_per_topic`
- `mail_daily_summary_min_excerpt_length`
- `mail_daily_summary_max_excerpt_length`
- `mail_daily_summary_preview_uses_daily_summary`

## User Preferences UI

In email preferences, users get:

- a checkbox to enable/disable Activity Update emails
- a frequency selector: `Site Default`, `Daily`, `Weekly`

## Template and Rendering Notes

- Uses dedicated daily summary templates in this plugin.
- Subject line changes based on frequency (`daily`/`weekly`).
- Excerpts can be constrained with min/max settings.
- `mail_daily_summary_max_posts_per_topic` limits posts shown per topic when > 0.