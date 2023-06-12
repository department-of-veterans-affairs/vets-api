# frozen_string_literal: true

module FormsApi
  class VBA21p0847
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def metadata
      {
        'veteranFirstName' => data.dig('veteran_full_name', 'first'),
        'veteranLastName' => data.dig('veteran_full_name', 'last'),
        'fileNumber' => data['veteran_va_file_number'].presence || data['veteran_ssn'],
        'zipCode' => data.dig('preparer_address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end
  end
end
