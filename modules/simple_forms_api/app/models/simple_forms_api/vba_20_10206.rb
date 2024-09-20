# frozen_string_literal: true

module SimpleFormsApi
  class VBA2010206 < VBA::Base
    STATS_KEY = 'api.simple_forms_api.20_10206'

    def initialize(data)
      super(data)

      @identity = data['preparer_type']
      @country = data.dig('address', 'country')
    end

    def metadata
      {
        'veteranFirstName' => data.dig('full_name', 'first'),
        'veteranLastName' => data.dig('full_name', 'last'),
        'fileNumber' => fetch_nested_value(%w[citizen_id ssn], %w[citizen_id va_file_number], %w[non_citizen_id arn]),
        'zipCode' => data.dig('address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => data['form_number'],
        'businessLine' => 'CMP'
      }
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
  end
end
