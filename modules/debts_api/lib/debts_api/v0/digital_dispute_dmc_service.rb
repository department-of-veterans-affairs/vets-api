require 'debt_management_center/base_service'
require 'debts_api/v0/digital_dispute_submission'

module DebtsApi
  module V0
    class DigitalDisputeDmcService < DebtManagementCenter::BaseService
      def initialize(user, submission)
        super(user)
        @submission = submission
      end

      def call!
        send_to_dmc

        in_progress_form&.destroy
        @submission.register_success
      rescue => e
        @submission.register_failure(e.message)
        Rails.logger.error("DigitalDisputeDmcService error: #{e.message}")
        raise e
      end

      def send_to_dmc
        measure_latency("#{DebtsApi::V0::DigitalDispute::STATS_KEY}.vba.latency") do
          perform(:post, 'dispute-debt', build_payload)
        end
      end

      def build_payload
        {
          fileNumber: @file_number,
          disputePDFs: files.map do |file|
            file.tempfile.rewind
            {
              fileName: sanitize_filename(file.original_filename),
              fileContents: Base64.strict_encode64(file.read)
            }
          end
        }
      end

      def in_progress_form
        InProgressForm.form_for_user('DISPUTE-DEBT', @user)
      end
    end
  end
end
