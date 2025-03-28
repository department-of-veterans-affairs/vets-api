# frozen_string_literal: true

require 'sidekiq'

module Organizations
  class QueueUpdates
    include Sidekiq::Job

    SLICE_SIZE = 30

    def perform
      file_content = fetch_file_content
      return unless file_content

      processed_data = Organizations::XlsxFileProcessor.new(file_content).process
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

      Organizations::XlsxFileProcessor::SHEETS_TO_PROCESS.each do |sheet|
        next if data[sheet].blank?

        batch = Sidekiq::Batch.new
        batch.description = "Batching #{sheet} sheet data"

        begin
          batch.jobs do
            rows_to_process(data[sheet]).each_slice(SLICE_SIZE) do |rows|
              json_rows = rows.to_json
              Organizations::Update.perform_in(delay.minutes, json_rows)
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
        org = Veteran::Service::Organization.find_by!(poa: row[:id])
        diff = org.diff(row)
        row.merge(diff.merge({ address_exists: org.location.present? })) if diff.values.any?
      rescue ActiveRecord::RecordNotFound => e
        log_error("Error: Organization not found #{e.message}")
        nil
      end.compact
    end

    def log_error(message)
      Rails.logger.error("QueueUpdates error: #{message}")
    end
  end
end
