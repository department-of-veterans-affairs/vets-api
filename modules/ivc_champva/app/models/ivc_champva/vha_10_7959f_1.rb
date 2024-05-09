# frozen_string_literal: true

module IvcChampva
  class VHA107959f1
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid
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
        'primary_contact_info' => @data['primary_contact_info']
      }
    end

    def submission_date_config
      { should_stamp_date?: false }
    end

    def method_missing(_, *args)
      args&.first
    end

    def respond_to_missing?(_)
      true
    end
  end
end
