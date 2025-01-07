# frozen_string_literal: true

require 'csv'
require 'aws-sdk-s3'

module Remediation
  class Process0781
    def self.run
      Rails.application.config.after_initialize do
        submission_ids = load_ids_from_csv

        ActiveRecord::Base.transaction do
          ActiveRecord::Base.connection.execute('SET TRANSACTION READ ONLY')

          submission_ids.each do |submission_id|
            submission = Form526Submission.find(submission_id)
            submission_date = submission.created_at

            if submission_date < Date.new(2019, 6, 24)
              # Pre-2019-06-24 submissions: form_key is implicitly 'form0781'
              form_id = EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781
              form_content = JSON.parse(submission.form_to_json(Form526Submission::FORM_0781))

              process_and_upload(submission, form_id, form_content)
            else
              {
                'form0781' => EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781,
                'form0781a' => EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781A,
                'form0781v2' => EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781V2
              }.each do |form_key, form_id|
                form_content = JSON.parse(submission.form_to_json(Form526Submission::FORM_0781))[form_key]
                next if form_content.blank?

                process_and_upload(submission, form_id, form_content)
              end
            end
          rescue => e
            Rails.logger.error("Error processing submission_id: #{submission_id}: #{e.message}")
            Rails.logger.error(e.backtrace.join("\n"))
          ensure
            File.delete(*Rails.root.glob('tmp/*.pdf'))
          end
        end
      end
    end

    def self.process_and_upload(submission, form_id, form_content)
      submitted_claim_id = submission.submitted_claim_id
      submission_id = submission.id
      Rails.logger.info("Processing submission_id: #{submission_id}, form_id: #{form_id}")

      pdf_path = EVSS::DisabilityCompensationForm::SubmitForm0781.new.send(:process_0781,
                                                                           submitted_claim_id,
                                                                           form_id,
                                                                           form_content,
                                                                           upload: false)

      Rails.logger.info("PDF generated at: #{pdf_path}")

      upload_to_s3(pdf_path, submission_id,
                   form_id)
      Rails.logger.info("PDF uploaded to S3 for submission_id: #{submission_id}, form_id: #{form_id}")
    end

    def self.load_ids_from_csv
      ids = []
      csv_file_path = Rails.root.join('tmp',
                                      '781_ids.csv')
      CSV.foreach(csv_file_path,
                  headers: true) do |row|
        ids << row['submission_id']
      end
      ids
    end

    def self.upload_to_s3(file_path, submission_id, form_id)
      s3_resource = Aws::S3::Resource.new(
        region: Settings.reports.aws.region,
        access_key_id: Settings.reports.aws.access_key_id,
        secret_access_key: Settings.reports.aws.secret_access_key
      )

      file_name = File.basename(file_path)
      s3_key = "remediation/0781/20250117/#{submission_id}/#{form_id}-#{file_name}"

      obj = s3_resource.bucket(Settings.reports.aws.bucket).object(s3_key)
      obj.upload_file(file_path,
                      content_type: 'application/pdf')

      # Delete the local file after successful upload
      File.delete(file_path)
    rescue => e
      Rails.logger.error("Error uploading to S3 or deleting file: #{file_path}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise e # Re-raise the exception to halt further processing
    end
  end
end
