import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-mail-daily-summary";

export default {
  name: "mail_daily_summary",
  initialize(container) {
    withPluginApi("1.2.0", (api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "envelope");
      api.addSaveableCustomFields("emails");
    });
  },
};
