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

  desc 'Delete malformed saved claims'
  task delete_malformed_saved_claims: :environment do
    edu_claims = EducationBenefitsClaim.includes(:saved_claim)
                                       .where(saved_claims: { form_id: LIVE_FORM_TYPES, created_at: nil })
                                       .where(processed_at: SPOOL_DATE.beginning_of_day..SPOOL_DATE.end_of_day).all

    saved_claims = edu_claims.map(&:saved_claim)
    submissions = edu_claims.map(&:education_benefits_submission)

    EducationBenefitsSubmission.delete(submissions)
    SavedClaim.delete(saved_claims)
    EducationBenefitsClaim.delete(edu_claims)
  end

  desc 'Rerun spool file for a specific day'
  task create_spool_files_for_date: :environment do
    require 'tmpdir'

    regional_data = EducationBenefitsClaim.includes(:saved_claim)
                                          .where(saved_claims: { form_id: LIVE_FORM_TYPES })
                                          .where(processed_at: SPOOL_DATE.beginning_of_day..SPOOL_DATE.end_of_day)
                                          .group_by { |r| r.regional_processing_office.to_sym }

    format_records(regional_data).each do |region, records|
      region_id = EducationFacility.facility_for(region: region)

      filename = Dir.tmpdir + "/#{region_id}_#{SPOOL_DATE.strftime('%m%d%Y')}_vetsgov.spl"
      contents = records.map(&:text).join(EducationForm::WINDOWS_NOTEPAD_LINEBREAK)

      File.open(filename, 'w') { |file| file.write(contents) }
    end
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
