import { observes } from "discourse-common/utils/decorators";
import EmailPreferencesController from 'discourse/controllers/preferences/emails';
import UserController from 'discourse/controllers/user';
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: 'mail_daily_summary',
  initialize(container){
    withPluginApi("1.2.0", (api) => {
      api.registerValueTransformer(
        "preferences-save-attributes",
        ({ value: attrs, context }) => {
          if (context.page === "emails") {
            attrs.push("custom_fields");
          }
          return attrs;
        }
      );
    });

    EmailPreferencesController.reopen({
      userMLMDailySummaryEnabled(){
        const user = this.get("model");
        return user.get("custom_fields.user_mlm_daily_summary_enabled");
      },

      @observes("model.custom_fields.user_mlm_daily_summary_enabled")
      _setUserMLMDailySummary(){
        var attrNames = this.get("saveAttrNames");
        attrNames.push('custom_fields');
        const user = this.get("model");
        var userMLMDailySummaryEnabled = user.custom_fields.user_mlm_daily_summary_enabled;
        if (userMLMDailySummaryEnabled === undefined) {
          const siteSettings = container.lookup("service:site-settings");
          userMLMDailySummaryEnabled = siteSettings.mail_daily_summary_enable_as_default;
        }
        user.set("custom_fields.user_mlm_daily_summary_enabled", userMLMDailySummaryEnabled);
      }
    })
  }
}
