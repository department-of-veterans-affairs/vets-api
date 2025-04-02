# frozen_string_literal: true

module SimpleFormsApi
  class VBA214138 < BaseForm
    STATS_KEY = 'api.simple_forms_api.21_4138'

    def desired_stamps
      [{
        coords: [[35, 220]],
        text: data['statement_of_truth_signature'],
        page: 1
      }]
    end

    def submission_date_stamps(timestamp = Time.current)
      [
        {
          coords: [460, 710],
          text: 'Application Submitted:',
          page: 0,
          font_size: 12
        },
        {
          coords: [460, 690],
          text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
          page: 0,
          font_size: 12
        }
      ]
    end

    def metadata
      {
        'veteranFirstName' => notification_first_name,
        'veteranLastName' => data.dig('full_name', 'last'),
        'fileNumber' => data.dig('id_number', 'va_file_number').presence || data.dig('id_number', 'ssn'),
        'zipCode' => data.dig('mailing_address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def notification_first_name
      data.dig('full_name', 'first')
    end

    def notification_email_address
      data['email_address']
    end

    def zip_code_is_us_based
      data.dig('mailing_address', 'country') == 'USA'
    end

    def track_user_identity(confirmation_number); end
  end
end
