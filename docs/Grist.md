# Grist Installation and onboarding

1. Enable the application to be deployed. Grist ignores the "default app state" setting; it must always be turned on explicitly. In `liquid.ini`:

```
...
[apps]
...
grist = on
```

2. Set the support administrator's email address. If no email address is configured for the user, it must be set to `<username>@<domain>`.

```
[liquid]
...
grist_initial_admin = you@domain.com
```

3. Run the `./liquid deploy` command and wait for it to finish.

4. Login into Grist using the user that was configured above. The message on
   the screen should say `Welcome, Support!`. The account name can be
   fixed from the profile page.

5. Onboard more people onto the app by giving them access to "Use grist
   spreadsheets" in the home page admin site.

6. For each onboarded person, their email must be manually added to the Grist
   "Manage Team" screen by pasting in their emails. As before, if no email was
   configured for that user, the default email is `<username>@<domain>`.

7. After their additions to the team list, the users should see all team
   content. Further access consols can be configured in the app.
