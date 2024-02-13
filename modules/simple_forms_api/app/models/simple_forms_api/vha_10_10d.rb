# frozen_string_literal: true

module SimpleFormsApi
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
        'fileNumber' => @data.dig('veteran', 'va_claim_number').presence || @data.dig('veteran', 'ssn_or_tin'),
        'zipCode' => @data.dig('veteran', 'address', 'postal_code') || '00000',
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def submission_date_config
      { should_stamp_date?: false }
    end

    def track_user_identity; end
  end
end
