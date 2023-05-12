# frozen_string_literal: true

module FormsApi
  class VHA1010d
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran', 'full_name', 'first'),
        'veteranLastName' => @data.dig('veteran', 'full_name', 'last'),
        'fileNumber' => @data.dig('veteran', 'va_claim_number').presence || @data.dig('veteran', 'ssn'),
        'zipCode' => @data.dig('veteran', 'address', 'postal_code'),
        'source' => 'forms_api',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end
  end
end
