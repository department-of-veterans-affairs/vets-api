# frozen_string_literal: true

require 'debt_management_center/base_service'
require 'debts_api/v0/digital_dispute_submission'

module DebtsApi
  module V0
    class DigitalDisputeDmcService < DebtManagementCenter::BaseService
      configuration DebtManagementCenter::DebtsConfiguration

      def initialize(user, submission)
        super(user)
        @submission = submission
      end

      def call!
        send_to_dmc
      rescue => e
        Rails.logger.error <<~LOG
          DigitalDisputeDmcService error: #{e.class} - #{e.message}
          #{e.backtrace&.take(12)&.join("\n")}
        LOG
        raise e
      end

      def send_to_dmc
        measure_latency("#{DebtsApi::V0::DigitalDisputeSubmission::STATS_KEY}.vba.latency") do
          perform(:post, 'dispute-debt', build_payload)
        end
      end

      def build_payload
        {
          fileNumber: @file_number,
          disputePDFs: @submission.files.map do |att|
            {
              fileName: sanitize_filename(att.filename.to_s),
              fileContents: Base64.strict_encode64(att.blob.download)
            }
          end
        }
      end

      def sanitize_filename(filename)
        name = File.basename(filename)
        name = name.tr(':', '_')
        name.gsub(/[.](?=.*[.])/, '')
      end
    end
  end
end
