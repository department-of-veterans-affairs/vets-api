# frozen_string_literal: true

require 'debts_api/v0/financial_status_report_service'

module DebtsApi
  class V0::DigitalDisputeJob

    sidekiq_retries_exhausted do |job, ex|
      user_data = job['args'][0]
      metadata = job['args'][2]

      debt_ids =
        if metadata.is_a?(Hash)
          metadata[:disputes] || metadata['disputes']
        else
          nil
        end

      if user_data && debt_ids.present?
        submission = DebtsApi::V0::DigitalDisputeSubmission
                       .where(user_uuid: user_data['uuid'], debt_identifiers: debt_ids)
                       .order(created_at: :desc)
                       .first
        submission&.register_failure("Retries exhausted: #{ex.class}: #{ex.message}")
      end

      Rails.logger.error("DigitalDisputeJob retries exhausted: #{ex.class}: #{ex.message} | args=#{job['args'].inspect}")
    end

    def perform(user_data, files, metadata)
      user = OpenStruct.new(uuid: user_data['uuid'], ssn: user_data['ssn'], participant_id: user_data['participant_id'])

      decoded_files = files.map do |file|
        decoded_file(file)
      end

      service = DebtsApi::V0::DigitalDisputeSubmissionService.new(user, decoded_files, metadata)
      service.call
    end

    private

    def decoded_file(file_hash)
      tempfile = Tempfile.new(['upload', '.pdf'], binmode: true)
      tempfile.write(Base64.decode64(file_hash['fileContents']))
      tempfile.rewind

      ActionDispatch::Http::UploadedFile.new(
        filename: file_hash['fileName'],
        type: 'application/pdf',
        tempfile:,
        head: file_head(file_hash)
      )
    end

    def file_head(file_hash)
      [
        %(Content-Disposition: form-data; name="file"; filename="#{file_hash['fileName']}"),
        'Content-Type: application/pdf'
      ].join("\r\n") << "\r\n"
    end
  end
end
