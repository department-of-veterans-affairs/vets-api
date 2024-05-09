# frozen_string_literal: true

module IvcChampva
  class VHA107959c
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('applicant_name', 'first'),
        'veteranMiddleName' => @data.dig('applicant_name', 'middle'),
        'veteranLastName' => @data.dig('applicant_name', 'last'),
        'fileNumber' => @data['applicant_ssn'],
        'zipCode' => @data.dig('applicant_address', 'postal_code') || '00000',
        'country' => @data.dig('applicant_address', 'country') || 'USA',
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP',
        'uuid' => @uuid,
        'primary_contact_info' => @data['primary_contact_info']
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

    def method_missing(_, *args)
      args&.first
    end

    def respond_to_missing?(_)
      true
    end
  end
end
