# frozen_string_literal: true

module SimpleFormsApi
  class VHA107959c
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('applicants', 'full_name', 'first'),
        'veteranLastName' => @data.dig('applicants', 'full_name', 'last'),
        'fileNumber' => @data.dig('applicants', 'ssn_or_tin'),
        'zipCode' => @data.dig('applicants', 'address', 'postal_code') || '00000',
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def submission_date_stamps
      []
    end
  end
end
