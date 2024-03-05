# frozen_string_literal: true

module SimpleFormsApi
  class VBA2010206
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

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

    def submission_date_config
      {
        should_stamp_date?: true,
        page_number: 1,
        title_coords: [460, 710],
        text_coords: [460, 690]
      }
    end

    def track_user_identity; end
  end
end
