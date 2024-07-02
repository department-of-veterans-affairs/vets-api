# frozen_string_literal: true

module IvcChampva
  class VHA107959f1
    include Virtus.model(nullify_blank: true)

    attribute :data
    attr_reader :form_id

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid
      @form_id = 'vha_10_7959f_1'
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran', 'full_name', 'first'),
        'veteranMiddleName' => @data.dig('veteran', 'full_name', 'middle'),
        'veteranLastName' => @data.dig('veteran', 'full_name', 'last'),
        'fileNumber' => @data.dig('veteran', 'va_claim_number').presence || @data.dig('veteran', 'ssn'),
        'zipCode' => @data.dig('veteran', 'mailing_address', 'postal_code') || '00000',
        'country' => @data.dig('veteran', 'mailing_address', 'country') || 'USA',
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP',
        'uuid' => @uuid,
        'primaryContactInfo' => @data['primary_contact_info']
      }
    end

    def desired_stamps
      [{ coords: [26, 82.5], text: data['statement_of_truth_signature'], page: 0 }]
    end

    def method_missing(_, *args)
      args&.first
    end

    def respond_to_missing?(_)
      true
    end
  end
end
