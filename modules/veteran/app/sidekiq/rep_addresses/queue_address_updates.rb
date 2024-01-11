# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'
require 'roo'

module RepAddresses
  # A Sidekiq job class for processing address and email updates from an Excel file.
  # This job fetches the file content, processes each sheet, and enqueues updates.
  class QueueAddressUpdates
    include Sidekiq::Job
    include SentryLogging

    BATCH_SIZE = 5000

    # Performs the job of fetching and processing the file content.
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
      # RepAddresses::XlsxFileFetcher.new.fetch

      # BEGIN TEMPORARY CODE FOR LOCAL DEVELOPMENT
      file_path = '/Users/holdenhinkle/Downloads/2024-01-5_Accreditations_Sanitized.xlsx'
      # file_path = '/Users/holdenhinkle/Downloads/2023-11-08_Accreditations_Sanitized.xlsx'

      # Read the file content into a string
      File.read(file_path)
      # END TEMPORARY CODE FOR LOCAL DEVELOPMENT
    end

    def queue_address_updates(data)
      RepAddresses::XlsxFileProcessor::SHEETS_TO_PROCESS.each do |sheet|
        next if data[sheet].empty?

        batch = Sidekiq::Batch.new
        batch.description = "Batching #{sheet} sheet data"

        data[sheet].each_slice(BATCH_SIZE) do |json_data|
          RepAddresses::UpdateAddresses.perform_async(json_data)
        end
      end
    end

    # Logs an error to Sentry.
    # @param message [String] The error message to be logged.
    def log_error(message)
      log_message_to_sentry("QueueAddressUpdates error: #{message}", :error)
    end
  end
end
