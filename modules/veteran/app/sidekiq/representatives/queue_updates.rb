# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'

module Representatives
  class QueueUpdates
    include Sidekiq::Job
    include SentryLogging

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
        slice_size = Settings.vsp_environment == 'production' ? 1000 : 30

        begin
          batch.jobs do
            rows_to_process(data[sheet]).each_slice(slice_size) do |rows|
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
      processed_rows = rows.map do |row|
        begin
          rep = Veteran::Service::Representative.find(row[:id])
          address_changed = address_changed?(rep, row[:request_address])
          email_changed = email_changed?(rep, row)
          phone_changed = phone_changed?(rep, row)
    
          if address_changed || email_changed || phone_changed
            # Return a new row with changed flags
            row.merge({
              address_changed: address_changed,
              email_changed: email_changed,
              phone_changed: phone_changed
            })
          else
            nil
          end
        rescue ActiveRecord::RecordNotFound => e
          log_error("Error: Representative not found #{e.message}")
          nil
        end
      end.compact

      processed_rows
    end
    
    def address_changed?(rep, row_address)
      rep_address = [rep.address_line1, rep.address_line2, rep.address_line3, rep.city, rep.zip_code, rep.zip_suffix].push(rep.state_code).join(' ')
      incoming_address = row_address.values_at(:address_line1, :address_line2, :address_line3, :city, :zip_code5, :zip_code4).push(row_address.dig(:state_province, :code)).join(' ')
      rep_address != incoming_address
    end

    def email_changed?(rep, row)
      rep.email != row[:email_address]
    end

    def phone_changed?(rep, row)
      rep.phone_number != row[:phone_number]
    end

    def log_error(message)
      log_message_to_sentry("QueueUpdates error: #{message}", :error)
    end
  end
end
