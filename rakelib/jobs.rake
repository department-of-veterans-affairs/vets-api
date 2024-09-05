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

  desc 'Populate facility dental service cache'
  task pull_facility_dental_service: :environment do
    Facilities::DentalServiceReloadJob.perform_async
  end

  desc 'Populate facility mental health data cache'
  task pull_facility_mental_health_phone: :environment do
    Facilities::MentalHealthReloadJob.perform_async
  end

  desc 'Populate/refresh NCA facility location to db cache'
  task pull_nca_data: :environment do
    Facilities::FacilityLocationDownloadJob.perform_async('nca')
  end

  desc 'Populate/refresh VBA facility location to db cache'
  task pull_vba_data: :environment do
    Facilities::FacilityLocationDownloadJob.perform_async('vba')
  end

  desc 'Populate/refresh VC facility location to db cache'
  task pull_vc_data: :environment do
    Facilities::FacilityLocationDownloadJob.perform_async('vc')
  end

  desc 'Populate/refresh VHA facility location to db cache'
  task pull_vha_data: :environment do
    Facilities::FacilityLocationDownloadJob.perform_async('vha')
  end

  desc 'Populate/reload NCA state cemetery data to db cache'
  task reload_nca_state_data: :environment do
    Facilities::StateCemeteryReloadJob.perform_async
  end

  desc 'Populate/refresh All facility location types to db cache'
  task pull_all_facility_location_data:
           %i[pull_nca_data pull_vba_data pull_vc_data pull_vha_data pull_drive_time_bands] do
    # run all dependencies
  end

  desc 'Populate/refresh Drive time bands'
  task pull_drive_time_bands: :environment do
    Facilities::PSSGDownload.perform_async
  end

  desc 'Process 10203 submissions for automated decision'
  task process_10203_submissions: :environment do
    EducationForm::Process10203Submissions.perform_async
  end

  desc 'Remove SpoolFileEvent rows for today so the create_daily_spool_files rake task can rerun'
  task reset_daily_spool_files_for_today: :environment do
    raise Common::Exceptions::Unauthorized if Settings.vsp_environment.eql?('production') # only allowed for test envs

    SpoolFileEvent.where('DATE(successful_at) = ?', Date.current).delete_all
  end
end
