# frozen_string_literal: true

module SimpleFormsApi
  class VBA214138
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def submission_date_stamps
      []
    end

    def metadata
      {
        'ƒirstName' => @data.dig('full_name', 'first'),
        'lastName' => @data.dig('full_name', 'last'),
        'fileNumber' => @data.dig('id_number', 'va_file_number').presence || @data['ssn'],
        'zipCode' => @data.dig('address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end
  end
end
