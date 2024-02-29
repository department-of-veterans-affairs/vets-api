# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'

module Representatives
  class QueueUpdates
    include Sidekiq::Job
    include SentryLogging

    SLICE_SIZE = 30

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

        begin
          batch.jobs do
            rows_to_process(data[sheet]).each_slice(SLICE_SIZE) do |rows|
              json_rows = rows.to_json
              Representatives::Update.perform_in(delay.minutes, json_rows)
              delay += 1
            end
          end
        rescue => e
          log_error("Error queuing address updates: #{e.message}")
        end
      end
    end

    def rows_to_process(rows)
      rows.map do |row|
        rep = Veteran::Service::Representative.find(row[:id])
        diff = rep.diff(row)
        row.merge(diff.merge({ address_exists: rep.location.present? })) if diff.values.any?
      rescue ActiveRecord::RecordNotFound => e
        log_error("Error: Representative not found #{e.message}")
        nil
      end.compact
    end

    def log_error(message)
      log_message_to_sentry("QueueUpdates error: #{message}", :error)
    end
  end
end
