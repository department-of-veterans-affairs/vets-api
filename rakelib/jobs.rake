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

  desc 'Process 10203 submissions for automated decision'
  task process_10203_submissions: :environment do
    EducationForm::Process10203Submissions.perform_async
  end

  desc 'Remove SpoolFileEvent rows for today so the create_daily_spool_files rake task can rerun'
  task reset_daily_spool_files_for_today: :environment do
    raise Common::Exceptions::Unauthorized if Settings.vsp_environment.eql?('production') # only allowed for test envs

    SpoolFileEvent.where('DATE(successful_at) = ?', Date.current).delete_all
  end

  desc 'Create daily excel files'
  task create_daily_excel_files: :environment do
    EducationForm::CreateDailyExcelFiles.perform_async
  end

  desc 'Remove ExcelFileEvent rows for today so the create_daily_excel_files rake task can rerun'
  task reset_daily_excel_files_for_today: :environment do
    raise Common::Exceptions::Unauthorized if Settings.vsp_environment.eql?('production') # only allowed for test envs

    ExcelFileEvent.where('DATE(successful_at) = ?', Date.current).delete_all
  end
end
