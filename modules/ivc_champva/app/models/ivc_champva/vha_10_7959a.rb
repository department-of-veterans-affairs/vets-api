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
      @form_id = 'vha_10_7959a'
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran', 'full_name', 'first'),
        'veteranLastName' => @data.dig('veteran', 'full_name', 'last'),
        'fileNumber' => @data.dig('veteran', 'va_file_number').presence || @data.dig('veteran', 'ssn'),
        'zipCode' => @data.dig('veteran', 'address', 'postal_code'),
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
        'country' => @data.dig('applicant_address', 'country') || 'USA',
        'uuid' => @uuid,
        'primaryContactInfo' => @data['primary_contact_info']
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
