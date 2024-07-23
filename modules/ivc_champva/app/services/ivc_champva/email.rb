# frozen_string_literal: true

module IvcChampva
  class Email
    attr_reader :data

    FORM_NAME_MAP = {
      '10-10D' => 'Application for CHAMPVA Benefits',
      '10-7959F-1' => 'Foreign Medical Program (FMP) Registration Form',
      '10-7959F-2' => 'Foreign Medical Program (FMP) Claim Cover Sheet',
      '10-7959C' => 'Other Health Insurance (OHI) Certification',
      '10-7959A' => 'CHAMPVA Claim Form'
    }.freeze

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
            'form_name' => FORM_NAME_MAP[data[:form_number]],
            'first_name' => data[:first_name],
            'last_name' => data[:last_name],
            'file_count' => data[:file_count],
            'pega_status' => data[:pega_status],
            'date_submitted' => data[:created_at]
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
