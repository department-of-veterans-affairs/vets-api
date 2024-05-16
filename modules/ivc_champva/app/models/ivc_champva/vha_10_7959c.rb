# frozen_string_literal: true

module IvcChampva
  class VHA107959c
    include Virtus.model(nullify_blank: true)

    attribute :data
    attr_reader :form_id

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid
      @form_id = 'vha_10_7959c'
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('applicants', 'full_name', 'first'),
        'veteranMiddleName' => @data.dig('applicants', 'full_name', 'middle'),
        'veteranLastName' => @data.dig('applicants', 'full_name', 'last'),
        'fileNumber' => @data.dig('applicants', 'ssn_or_tin'),
        'zipCode' => @data.dig('applicants', 'address', 'postal_code') || '00000',
        'country' => @data.dig('applicants', 'address', 'country') || 'USA',
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

    def method_missing(_, *args)
      args&.first
    end

    def respond_to_missing?(_)
      true
    end
  end
end
