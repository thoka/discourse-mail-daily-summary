Fork of [discourse-mlm-summary](https://github.com/procourse/discourse-mlm-daily-summary), working on added/changed behaviour:

- send daily/weekly summary at a specified time of day
- optional diagnostic output to support configuration and troubleshooting
- daily summaries can be forced for user groups: mail_daily_summary_auto_enabled_groups
- daily summaries can be narrowed to categories (including all subcategories): mail_daily_summary_enabled_categories
- time of last run will be remembered in mail_daily_summary_last_run_at
  Messages between sending time and mail_daily_summary_last_run_at will be included in the summary if set. Otherwise changes in the last 24 hours / 7 days will be send.
- optionally enable it for all users (opt out)
- message template is based on current (2024-04-30) digest template
- unsubscribe link added
- this plugin ignores the "disable mailing list mode" setting

## Changelog

- add weekly summaries (0.12)

## ToDo / Wishes

- add option to notify only about subscribed categories
- add configuration option to exclude groups 
- add configuration option to exclude categories
- add possibility to respond to individual topics/posts by mail
- add specs


