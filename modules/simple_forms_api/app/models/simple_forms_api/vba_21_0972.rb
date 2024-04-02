# frozen_string_literal: true

module SimpleFormsApi
  class VBA210972
    include Virtus.model(nullify_blank: true)
    STATS_KEY = 'api.simple_forms_api.21_0972'

    attribute :data

    def initialize(data)
      @data = data
    end

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

    def zip_code_is_us_based
      @data.dig('preparer_address', 'country') == 'USA'
    end

    def submission_date_config
      {
        should_stamp_date?: true,
        page_number: 1,
        title_coords: [440, 690],
        text_coords: [440, 670]
      }
    end

    def track_user_identity(confirmation_number)
      identity = data['claimant_identification']
      StatsD.increment("#{STATS_KEY}.#{identity}")
      Rails.logger.info('Simple forms api - 21-0972 submission user identity', identity:, confirmation_number:)
    end
  end
end
