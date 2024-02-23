# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'

module Representatives
  class QueueUpdates
    include Sidekiq::Job
    include SentryLogging

    BATCH_SIZE = 30

    def perform
      file_content = fetch_file_content
      return unless file_content

      processed_data = Representatives::XlsxFileProcessor.new(file_content).process
      queue_address_updates(processed_data)
    rescue => e
      log_error("Error in file fetching process: #{e.message}")
    end

    private

    def fetch_file_content
      Representatives::XlsxFileFetcher.new.fetch
    end

    def queue_address_updates(data)
      delay = 0

      Representatives::XlsxFileProcessor::SHEETS_TO_PROCESS.each do |sheet|
        next if data[sheet].blank?

        batch = Sidekiq::Batch.new
        batch.description = "Batching #{sheet} sheet data"

        batch.jobs do
          data[sheet].each_slice(BATCH_SIZE) do |rows|
            Representatives::UpdateBatch.perform_in(delay.minutes, rows)
            delay += 1
          end
        end
      end
    end

    def log_error(message)
      log_message_to_sentry("QueueUpdates error: #{message}", :error)
    end
  end
end
