# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'

module RepAddresses
  class QueueAddressUpdates
    include Sidekiq::Job
    include SentryLogging

    BATCH_SIZE = 5000

    def perform
      file_content = fetch_file_content
      return unless file_content

      processed_data = RepAddresses::XlsxFileProcessor.new(file_content).process
      queue_address_updates(processed_data)
    rescue => e
      log_error("Error in file fetching process: #{e.message}")
    end

    private

    def fetch_file_content
      RepAddresses::XlsxFileFetcher.new.fetch
    end

    def queue_address_updates(data)
      RepAddresses::XlsxFileProcessor::SHEETS_TO_PROCESS.each do |sheet|
        next if data[sheet].empty?

        batch = Sidekiq::Batch.new
        batch.description = "Batching #{sheet} sheet data"

        batch.jobs do
          data[sheet].each_slice(BATCH_SIZE) do |rows|
            rows.each do |row|
              RepAddresses::UpdateAddresses.perform_async(row)
            end
          end
        end
      end
    end

    def log_error(message)
      log_message_to_sentry("QueueAddressUpdates error: #{message}", :error)
    end
  end
end
