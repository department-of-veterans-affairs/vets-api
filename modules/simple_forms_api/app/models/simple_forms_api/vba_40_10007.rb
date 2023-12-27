# frozen_string_literal: true

module SimpleFormsApi
  class VBA4010007
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('application', 'applicant', 'name', 'first')
        'veteranLastName' => @data.dig('application', 'applicant', 'name', 'last'),
        # 'fileNumber' => @data.dig('veteran', 'va_claim_number').presence || @data.dig('veteran', 'ssn'),
        # 'zipCode' => @data.dig('veteran', 'address', 'postal_code') || '00000',
        # 'source' => 'VA Platform Digital Forms',
        # 'docType' => @data['form_number'],
        # 'businessLine' => 'CMP'
      }
    end
  end
end