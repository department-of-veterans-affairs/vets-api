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

  LIVE_FORM_TYPES = %w(1990 1995 1990e 5490 1990n 5495).map { |t| "22-#{t.upcase}" }.freeze
  SPOOL_DATE = '2017-10-26'.to_date

  desc 'Dry run removing saved claims on 2017-10-26'
  task check_malformed_claims: :environment do
    malformed = malformed_ids

    edu_claims = malformed[:education_benefits_claims]
    saved_claims = malformed[:saved_claims]
    edu_submissions = malformed[:education_benefits_submissions]
    confirmation_numbers = malformed[:confirmation_numbers]

    total = edu_claims.length + edu_submissions.length + saved_claims.length

    puts "Task would remove #{total} total rows"
    puts "\teducation_benefits_claims: #{edu_claims.length}"
    puts "\tsaved_claims: #{saved_claims.length}"
    puts "\teducation_benefits_submissions: #{edu_submissions.length}"

    write_confirmation_numbers(confirmation_numbers)
  end

  desc 'Delete malformed saved claims on 2017-10-26'
  task delete_malformed_claims: :environment do
    malformed = malformed_ids

    edu_claims = malformed[:education_benefits_claims]
    saved_claims = malformed[:saved_claims]
    edu_submissions = malformed[:education_benefits_submissions]
    confirmation_numbers = malformed[:confirmation_numbers]

    # Log confirmation_numbers to file
    write_confirmation_numbers(confirmation_numbers)

    EducationBenefitsSubmission.delete(edu_submissions)
    EducationBenefitsClaim.delete(edu_claims)
    SavedClaim.delete(saved_claims)
  end

  desc 'Rerun spool file for 2017-10-26'
  task recreate_spool_files: :environment do
    regional_data = EducationBenefitsClaim.includes(:saved_claim)
                                          .where(saved_claims: { form_id: LIVE_FORM_TYPES })
                                          .where(processed_at: SPOOL_DATE.beginning_of_day..SPOOL_DATE.end_of_day)
                                          .group_by { |r| r.regional_processing_office.to_sym }

    format_records(regional_data).each do |region, records|
      region_id = EducationForm::EducationFacility.facility_for(region: region)

      filename = tmp_dir + "/#{region_id}_#{SPOOL_DATE.strftime('%m%d%Y')}_vetsgov.spl"
      contents = records.map(&:text).join(EducationForm::WINDOWS_NOTEPAD_LINEBREAK)

      File.open(filename, 'w') { |file| file.write(contents) }
      puts "Wrote to #{filename}"
    end
  end

  def tmp_dir
    require 'tmpdir'
    Dir.mktmpdir
  end

  def malformed_records
    EducationBenefitsClaim.includes(:saved_claim)
                          .where(saved_claims: { form_id: LIVE_FORM_TYPES, created_at: nil })
                          .where(processed_at: SPOOL_DATE.beginning_of_day..SPOOL_DATE.end_of_day)
  end

  def malformed_ids
    edu_claims = []
    edu_submissions = []
    saved_claims = []
    confirmation_numbers = []

    malformed_records.find_each do |claim|
      edu_claims << claim.id
      edu_submissions << claim.education_benefits_submission&.id
      saved_claims << claim.saved_claim&.id
      confirmation_numbers << claim.confirmation_number
    end

    {
      education_benefits_claims: edu_claims.compact,
      education_benefits_submissions: edu_submissions.compact,
      saved_claims: saved_claims.compact,
      confirmation_numbers: confirmation_numbers.compact
    }
  end

  def write_confirmation_numbers(confirmation_numbers)
    filename = tmp_dir + '/confirmation_numbers.txt'
    File.open(filename, 'w') { |f| f.puts(confirmation_numbers) }
    puts "Wrote to #{filename}"
  end

  def format_records(grouped_data)
    raw_groups = grouped_data.each do |region, v|
      grouped_data[region] = v.map do |record|
        record.saved_claim.valid? && EducationForm::Forms::Base.build(record)
      end.compact
    end

    # delete any regions that only had malformed claims before returning
    raw_groups.delete_if { |_, v| v.empty? }
  end
end
