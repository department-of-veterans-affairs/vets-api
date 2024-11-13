# frozen_string_literal: true

module SimpleFormsApi
  class VBA2010206 < BaseForm
    STATS_KEY = 'api.simple_forms_api.20_10206'

    def metadata
      {
        'veteranFirstName' => @data.dig('full_name', 'first'),
        'veteranLastName' => @data.dig('full_name', 'last'),
        'fileNumber' => @data.dig(
          'citizen_id',
          'ssn'
        ) || @data.dig(
          'citizen_id',
          'va_file_number'
        ) || @data.dig(
          'non_citizen_id',
          'arn'
        ),
        'zipCode' => @data.dig('address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def zip_code_is_us_based
      @data.dig('address', 'country') == 'USA'
    end

    def desired_stamps
      []
    end

    def submission_date_stamps(timestamp = Time.current)
      [
        {
          coords: [460, 710],
          text: 'Application Submitted:',
          page: 1,
          font_size: 12
        },
        {
          coords: [460, 690],
          text: timestamp.in_time_zone('UTC').strftime('%H:%M %Z %D'),
          page: 1,
          font_size: 12
        }
      ]
    end

    def track_user_identity(confirmation_number)
      identity = data['preparer_type']
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('Simple forms api - 20-10206 submission user identity', identity:, confirmation_number:)
    end
  end
end
