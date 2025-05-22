# frozen_string_literal: true

require 'sidekiq'
require 'csv'
require 'claims_api/claim_logger'

module ClaimsApi
  module OneOff
    class PoaV1PdfGenFixupBatcherJob < ClaimsApi::ServiceBase
      include Sidekiq::Job
      # No need to retry and keep runs from stacking up
      sidekiq_options retry: false

      LOG_TAG = 'poa_v1_pdf_gen_fixup_batcher_job'

      # rubocop:disable Metrics/MethodLength
      def perform
        now = Time.current
        file = Rails.root.join(*%w[modules claims_api app sidekiq claims_api one_off poa_v1_pdf_gen_fixup_ids.csv])
        csv_data = CSV.read file, headers: true
        if csv_data.blank?
          msg = 'No IDs found in CSV file'
          ClaimsApi::Logger.log LOG_TAG, level: :error, detail: msg
          notify_on_failure LOG_TAG, msg
          return
        end

        ClaimsApi::Logger.log LOG_TAG, detail: "Found #{csv_data.size} IDs in CSV file"

        num_enqueued = 0
        Sidekiq::Batch.new.jobs do
          csv_data.each_with_index do |csv_row, i|
            # Run in 6 seconds intervals, as requested by Firefly, since that's what BDS can handle alongside its other
            # consumers' requests. Should push out the last regeneration to ~3.5 hours from batch job start time.
            ClaimsApi::OneOff::PoaV1PdfGenFixupJob.perform_in (i * 6).seconds, csv_row['poa_id']
            num_enqueued += 1
          end
        end
        ClaimsApi::Logger.log LOG_TAG, detail: "Successfully enqueued #{num_enqueued} PoaV1PdfGenFixupJob jobs"
        ClaimsApi::Logger.log LOG_TAG, detail: "Estimated completion time: #{now + (num_enqueued * 6).seconds}"
      rescue => e
        ClaimsApi::Logger.log LOG_TAG, level: :error, detail: 'Exception thrown', error_class: e.class.name,
                                       error: e.message
        ClaimsApi::Logger.log LOG_TAG, level: :error, detail: "Was able to enqueue #{num_enqueued} jobs"
        ClaimsApi::Logger.log LOG_TAG, level: :error,
                                       detail: "Estimated completion time: #{now + (num_enqueued * 6).seconds}"
        notify_on_failure LOG_TAG, "#{e.class.name} :: #{e.message}"
        raise
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
