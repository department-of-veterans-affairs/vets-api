# frozen_string_literal: true
namespace :edu do
  desc 'Given a confirmation number, print a spool file entry'
  task :print, [:id] => [:environment] do |_t, args|
    raise 'need to give an id. edu:print[{id}]' if args[:id].blank?
    id = args[:id].gsub(/\D/, '').to_i
    app = EducationBenefitsClaim.find(id)
    puts EducationForm::Forms::Base.build(app).text
  end

  # one off script for persistent attachment migrations, delete later
  desc 'migrate persistent attachments'
  task persistent_attachment: :environment do
    DataMigrations::PersistentAttachment.run
  end

  # one off script for spool submission report, delete later
  desc 'generate spool submissions report for last 60 days'
  task spool_report: :environment do
    class AllSpoolSubmissionsReportMailer < ApplicationMailer
      REPORT_TEXT = 'Spool submissions report'

      def build(report_file)
        url = Reports::Uploader.get_s3_link(report_file)

        opt = {
          to: 'lihan@adhocteam.us'
        }

        mail(
          opt.merge(
            subject: REPORT_TEXT,
            body: "#{REPORT_TEXT} (link expires in one week)<br>#{url}"
          )
        )
      end
    end

    require 'csv'

    def format_name(full_name)
      return if full_name.blank?

      [full_name['first'], full_name['last']].compact.join(' ')
    end

    csv_array = []
    csv_array << ['Claimant Name', 'Veteran Name', 'Confirmation #', 'Time Submitted', 'RPO']

    EducationBenefitsClaim.where(
      'processed_at IS NOT NULL'
    ).find_each do |education_benefits_claim|
      parsed_form = education_benefits_claim.parsed_form

      csv_array << [
        format_name(parsed_form['relativeFullName']),
        format_name(parsed_form['veteranFullName']),
        education_benefits_claim.confirmation_number,
        education_benefits_claim.processed_at.to_s,
        education_benefits_claim.regional_processing_office
      ]
    end

    folder = 'tmp/spool_reports'
    FileUtils.mkdir_p(folder)
    filename = "#{folder}/all_submissions.csv"
    CSV.open(filename, 'wb') do |csv|
      csv_array.each do |row|
        csv << row
      end
    end

    AllSpoolSubmissionsReportMailer.build(filename).deliver_now
  end
end
