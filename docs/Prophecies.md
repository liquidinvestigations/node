# Prophecies initial admin onboarding

1. In `liquid.ini` set `[apps] prophecies = on` and run `./liquid deploy`.

2. Login to Prophecies using a staff account and click the "Admin" page. It should be empty.

3. Promote your admin account to a Prophecies superuser: `./liquid dockerexec  prophecies:prophecies elevate_superuser.sh YOUR_USERNAME`.

4. You can now continue onboarding normally, giving people access through the "User" and "Groups" tables from the admin page.
