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

  desc 'Dry run removing saved claims on 2017-10-26'
  task check_malformed_claims: :environment do
    Rails.application.eager_load!

    malformed = EducationForm::GenerateSpoolFiles.new.malformed_claim_ids

    puts malformed
    edu_claims = malformed[:education_benefits_claims]
    saved_claims = malformed[:saved_claims]
    edu_submissions = malformed[:education_benefits_submissions]

    total = edu_claims.length + edu_submissions.length + saved_claims.length

    puts "\nTask would remove #{total} total rows"
    puts "\teducation_benefits_claims: #{edu_claims.length}"
    puts "\tsaved_claims: #{saved_claims.length}"
    puts "\teducation_benefits_submissions: #{edu_submissions.length}"
  end

  desc 'Delete malformed saved claims on 2017-10-26'
  task delete_malformed_claims: :environment do
    Rails.application.eager_load!

    result = EducationForm::GenerateSpoolFiles.new.delete_malformed_claims

    puts "Removed #{result[:count]} rows"
    puts "Wrote confirmation numbers to #{result[:filename]}"
  end

  desc 'Rerun spool file for 2017-10-26'
  task recreate_spool_files: :environment do
    Rails.application.eager_load!

    results = EducationForm::GenerateSpoolFiles.new.generate_spool_files

    results.each do |r|
      puts "Wrote #{r[:count]} applications for region #{r[:region]} to #{r[:filename]}"
    end
  end

  desc 'Generate and upload region 331 and 351 spool files'
  task upload_spool_files: :environment do
    Rails.application.eager_load!

    results = EducationForm::GenerateSpoolFiles.new.upload_spool_files

    results.each do |r|
      puts "Wrote #{r[:count]} applications for region #{r[:region]} to #{r[:filename]}"
    end
  end
end
