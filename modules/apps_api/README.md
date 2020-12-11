# Apps Api

This project uses MIT-LICENSE.

## Local Testing

### Populating Rails DB

The applications stored in the Application Directory are stored in the `directory_applications` table. If running `sidekiq`, the job to populate the table runs `1m` after server start.
In order to populate the table locally without running `sidekiq`, open a `rails console` and do the following.
```
a = AppsApi::DirectoryLoader.new
a.perform
```
Check for success by calling `DirectoryApplication.all`, each application listed in `modules/apps_api/lib/apps_api/directory_application_creator.rb` should be displayed.

### Testing Okta Notification Event Hook

1. Install [ngrok](https://ngrok.com/)
2. `ngrok http http://localhost:3000 -host-header=localhost`
3. Use forwarding url given by ngrok as base url for HTTP requests.
     - Example: `https://f1ce959387d9.ngrok.io`
