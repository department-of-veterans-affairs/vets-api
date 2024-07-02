# frozen_string_literal: true

module IvcChampva
  class VHA107959c
    include Virtus.model(nullify_blank: true)
    include Attachments

    attribute :data
    attr_reader :form_id

    def initialize(data)
      @data = data
      @uuid = SecureRandom.uuid
      @form_id = 'vha_10_7959c'
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
        'primaryContactInfo' => @data['primary_contact_info']
      }
    end

    # rubocop:disable Naming/BlockForwarding,Style/HashSyntax
    def method_missing(method_name, *args, &block)
      super unless respond_to_missing?(method_name)
      { method: method_name, args: args }
    end
    # rubocop:enable Naming/BlockForwarding,Style/HashSyntax

    def respond_to_missing?(_method_name, _include_private = false)
      true
    end
  end
end
