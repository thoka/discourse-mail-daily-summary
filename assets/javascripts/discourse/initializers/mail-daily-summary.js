import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "mail_daily_summary",
  initialize(container) {
    withPluginApi("1.2.0", (api) => {
      api.addSaveableCustomFields("emails");
    });
  },
};
