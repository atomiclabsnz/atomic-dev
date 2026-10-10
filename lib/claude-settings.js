// Add the IDE's Notification hook to a Claude Code settings.json, keeping everything else.
// Usage: node claude-settings.js SETTINGS_JSON HOOK_COMMAND   (exit 0 = changed, 3 = already there)
const fs = require("fs");
const [file, command] = process.argv.slice(2);
let settings = {};
if (fs.existsSync(file)) settings = JSON.parse(fs.readFileSync(file, "utf8"));
settings.hooks ??= {};
settings.hooks.Notification ??= [];
if (JSON.stringify(settings.hooks.Notification).includes(command)) process.exit(3);
settings.hooks.Notification.push({
  matcher: "permission_prompt|idle_prompt|elicitation_dialog",
  hooks: [{ type: "command", command }],
});
fs.writeFileSync(file, JSON.stringify(settings, null, 2) + "\n");
