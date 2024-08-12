# Education Form Serialization & Submission

* A series of Spool Files are created with applications grouped into regions
  * The files are created from individual applications stored in the database for a given day
  * The applications are stored in a format that matches the edu-benefits schema in the vets-json-schema repo
  * The applications are formatted and concatenated using the 22-1990.erb template
  * The file must use windows-style newlines, and have a maximum line length of 78 characters before the newlines

* The generated files are SFTPed to a remote system or systems.

## Testing Locally

If you want to generate spool files locally, you have two options:

* With at least Sidekiq running, run `rake jobs:create_daily_spool_files`
* With a rails console (`bin/rails c`), run `EducationForm::CreateDailySpoolFiles.new.perform`

The files will be written into `tmp/spool_files`, with each regional file starting with the current date.

Important!!! in config/environments/development.rb set config.eager_load = true or the job will NOT run correctly.

## Reprocessing an application

If an application needs to go to a different processing center, we can take the ID and queue it up to be sent over the next time the spool file job runs:

```
application_id = ###
new_region = one of 'eastern', 'western', or 'central'
application = EducationBenefitsClaim.find(application_id)
application.reprocess_at(region)
```

## Rerunning the job for a day (non production only)

As designed, the Daily Spool File Job only runs once a day. To rerun:

* Run `jobs:reset_daily_spool_files_for_today`
* do either of the two options under Testing Locally
