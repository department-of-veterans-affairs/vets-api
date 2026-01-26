# frozen_string_literal: true

require 'sidekiq'

module Representatives
  class QueueUpdates
    include Sidekiq::Job

    SLICE_SIZE = 30

    attr_accessor :rows, :slices, :slack_messages

    def initialize
      @rows = 0
      @slices = 0
      @slack_messages = []
    end

    def perform
      file_content = fetch_file_content
      return unless file_content

      processed_data = Representatives::XlsxFileProcessor.new(file_content).process
      queue_address_updates(processed_data)
    rescue => e
      log_error("Error in file fetching process: #{e.message}")
    ensure
      if @slack_messages.any? # Only report if we have errors
        @slack_messages.unshift("Processed #{@rows} rows in #{@slices} slices")
        @slack_messages.unshift('Representatives::QueueUpdates')
        log_to_slack(@slack_messages.join("\n"))
      end
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
              @slices += 1
              @rows += rows.size
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

        # Compute diff BEFORE updating raw_address so address_changed detection works correctly
        diff = rep.diff(row)

        # Update raw_address for every record to keep it in sync with XLSX source
        rep.update(raw_address: row[:raw_address]) if rep.raw_address != row[:raw_address]

        row.merge(diff.merge({ address_exists: rep.location.present? })) if diff.values.any?
      rescue ActiveRecord::RecordNotFound => e
        log_error("Error: Representative not found #{e.message}")
        nil
      end.compact
    end

    def log_error(message)
      message = "QueueUpdates error: #{message}"
      Rails.logger.error(message)
      @slack_messages << "----- #{message}"
    end

    def log_to_slack(message)
      return unless Settings.vsp_environment == 'production'

      client = SlackNotify::Client.new(webhook_url: Settings.edu.slack.webhook_url,
                                       channel: '#benefits-representation-management-notifications',
                                       username: 'Representatives::QueueUpdates Bot')
      client.notify(message)
    end
  end
end
