import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import { i18n } from "discourse-i18n";

@classNames("user-preferences-emails-outlet", "mail-daily-summary")
export default class MailDailySummaryConnector extends Component {
  toBoolean(value) {
    if (typeof value === "boolean") {
      return value;
    }

    if (typeof value === "string") {
      const normalized = value.toLowerCase();
      return normalized === "true" || normalized === "t" || normalized === "1";
    }

    return !!value;
  }

  get userMLMDailySummaryEnabled() {
    const value = this.model?.custom_fields?.user_mlm_daily_summary_enabled;

    if (value === undefined) {
      return this.toBoolean(this.siteSettings.mail_daily_summary_enable_as_default);
    }

    return this.toBoolean(value);
  }

  set userMLMDailySummaryEnabled(value) {
    const normalizedValue = this.toBoolean(value);
    this.model.set("custom_fields.user_mlm_daily_summary_enabled", normalizedValue);
    return normalizedValue;
  }

  <template>
    {{#if this.siteSettings.mail_daily_summary_enabled}}
      <div class="control-group">
        <label class="control-label">{{i18n "mail_daily_summary.daily"}}</label>
        <PreferenceCheckbox
          @labelKey="mail_daily_summary.preference_label"
          @checked={{this.userMLMDailySummaryEnabled}}
        />
        <div class="instructions">{{{i18n
            "mail_daily_summary.instructions"
          }}}</div>
      </div>
    {{/if}}
  </template>
}
