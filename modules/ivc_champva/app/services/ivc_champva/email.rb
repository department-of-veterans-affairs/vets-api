# frozen_string_literal: true

module IvcChampva
  class Email
    attr_reader :data

    def initialize(data)
      @data = data
    end

    def send_email
      Datadog::Tracing.trace('Send PEGA Status Update Email') do
        return unless valid_environment?

        VANotify::EmailJob.perform_async(
          data[:email],
          Settings.vanotify.services.ivc_champva.template_id.pega_status_update_email_template_id,
          {
            'form_number' => data[:form_number],
            'first_name' => data[:first_name],
            'last_name' => data[:last_name],
            'file_names' => data[:file_names].join("\n"),
            'pega_status' => data[:pega_status],
            'updated_at' => data[:updated_at]
          },
          Settings.vanotify.services.ivc_champva.api_key
        )
      rescue => e
        Rails.logger.error "Pega Status Update Email Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    private

    def valid_environment?
      %w[production staging].include?(Rails.env)
    end
  end
end
