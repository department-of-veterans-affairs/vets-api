# frozen_string_literal: true

module IvcChampva
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

    def submission_date_config
      {
        should_stamp_date?: false,
        page_number: 1,
        title_coords: [440, 690],
        text_coords: [440, 670]
      }
    end
  end
end
