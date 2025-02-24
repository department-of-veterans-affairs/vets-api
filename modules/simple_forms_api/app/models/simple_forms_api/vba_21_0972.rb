# frozen_string_literal: true

module SimpleFormsApi
  class VBA210972 < BaseForm
    STATS_KEY = 'api.simple_forms_api.21_0972'

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran_full_name', 'first'),
        'veteranLastName' => @data.dig('veteran_full_name', 'last'),
        'fileNumber' => @data['veteran_va_file_number'].presence || @data['veteran_ssn'],
        'zipCode' => @data.dig('preparer_address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def notification_first_name
      data.dig('preparer_full_name', 'first')
    end

    def notification_email_address
      data['preparer_email']
    end

    def zip_code_is_us_based
      @data.dig('preparer_address', 'country') == 'USA'
    end

    def desired_stamps
      [{ coords: [50, 465], text: data['statement_of_truth_signature'], page: 2 }]
    end

    def submission_date_stamps(timestamp)
      [
        {
          coords: [440, 690],
          text: 'Application Submitted:',
          page: 1,
          font_size: 12
        },
        {
          coords: [440, 670],
          text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
          page: 1,
          font_size: 12
        }
      ]
    end

    def track_user_identity(confirmation_number)
      identity = data['claimant_identification']
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('Simple forms api - 21-0972 submission user identity', identity:, confirmation_number:)
    end
  end
end
