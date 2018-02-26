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

  desc 'Populate/refresh NCA facility location to db cache'
  task pull_nca_data: :environment do
    Facilities::FacilityLocationDownload.perform_async('nca')
  end

  desc 'Populate/refresh VBA facility location to db cache'
  task pull_vba_data: :environment do
    Facilities::FacilityLocationDownload.perform_async('vba')
  end

  desc 'Populate/refresh VC facility location to db cache'
  task pull_vc_data: :environment do
    Facilities::FacilityLocationDownload.perform_async('vc')
  end

  desc 'Populate/refresh VHA facility location to db cache'
  task pull_vha_data: :environment do
    Facilities::FacilityLocationDownload.perform_async('vha')
  end

  desc 'Populate/refresh All facility location types to db cache'
  task pull_all_facility_location_data: %i[pull_nca_data pull_vba_data pull_vc_data pull_vha_data] do
    # run all dependencies
  end
end
