# frozen_string_literal: true

module SimpleFormsApi
  class VBA214138
    include Virtus.model(nullify_blank: true)
    STATS_KEY = 'api.simple_forms_api.21_4138'

    attribute :data

    def initialize(data)
      @data = data
    end

    def submission_date_stamps
      []
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('full_name', 'first'),
        'veteranLastName' => @data.dig('full_name', 'last'),
        'fileNumber' => @data.dig('id_number', 'va_file_number').presence || @data['ssn'],
        'zipCode' => @data.dig('address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def zip_code_is_us_based
      @data.dig('mailing_address', 'country') == 'USA'
    end

    def track_user_identity(confirmation_number); end
  end
end
