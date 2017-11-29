# frozen_string_literal: true
namespace :jobs do
  desc 'Create daily spool files'
  task create_daily_spool_files: :environment do
    EducationForm::CreateDailySpoolFiles.perform_async
  end

  desc 'Email daily year to date report'
  task create_daily_year_to_date_report: :environment do
    EducationForm::CreateDailyYearToDateReport.perform_async(Time.zone.today)
  end

  desc 'Populate facility access-to-care cache'
  task download_facility_access_data: :environment do
    Facilities::AccessDataDownload.perform_async
  end

  desc 'Get names and ssns of claims to be resubmitted'
  task write_ssns: :environment do
    Rails.application.eager_load!

    puts EducationForm::GenerateSpoolFiles.new.write_names_and_ssns
  end
end
