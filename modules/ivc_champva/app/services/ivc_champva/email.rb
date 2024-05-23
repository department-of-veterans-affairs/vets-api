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
          Settings.vanotify.services.va_gov.template_id.ivc_champva_form_callback_email,
          {
            'form_number' => data[:form_number],
            'first_name' => data[:first_name],
            'last_name' => data[:last_name],
            'file_names' => data[:file_names],
            'pega_status' => data[:pega_status],
            'updated_at' => data[:updated_at]
          }
        )
      rescue => e
        raise e.message.to_s
      end
    end

    private

    def valid_environment?
      %w[production staging].include?(Rails.env)
    end
  end
end
