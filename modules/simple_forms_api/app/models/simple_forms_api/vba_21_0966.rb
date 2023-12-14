# frozen_string_literal: true

module SimpleFormsApi
  class VBA210966
    include Virtus.model(nullify_blank: true)

    attribute :data

    def initialize(data)
      @data = data
    end

    def metadata
      {
        'veteranFirstName' => @data.dig('veteran_full_name', 'first'),
        'veteranLastName' => @data.dig('veteran_full_name', 'last'),
        'fileNumber' => @data.dig('veteran_id', 'va_file_number').presence || @data.dig('veteran_id', 'ssn'),
        'zipCode' => @data.dig('veteran_mailing_address', 'postal_code') ||
          @data.dig('surviving_dependent_mailing_address', 'postal_code') ||
          '00000',
        'source' => 'VA Platform Digital Forms',
        'docType' => @data['form_number'],
        'businessLine' => 'CMP'
      }
    end

    def relationship_to_veteran_radio
      relationship = @data.dig('relationship_to_veteran', 'relationship_to_veteran')
      ['', 'spouse', 'child'].find_index(relationship) if relationship
    end

    def relationship_to_veteran
      relationship = @data.dig('relationship_to_veteran', 'relationship_to_veteran')
      if ['parent', 'executor', 'other'].include?(relationship)
        relationship
      end
    end

    def third_party_info
      third_party_preparer_full_name = @data['third_party_preparer_full_name']
      role = if @data['third_party_preparer_role'] == 'other'
        @data['other_third_party_preparer_role'] || ''
      else
        @data['third_party_preparer_role'] || ''
      end

      if third_party_preparer_full_name
        (third_party_preparer_full_name['first'] || '') + ' '
          + (third_party_preparer_full_name['middle'] || '') + ' '
          + (third_party_preparer_full_name['last'] || '') + ', ' 
          + role
      end
    end
  end
end
