# frozen_string_literal: true

module BGSDependents
  class Marriage < Base
    attribute :ssn, String
    attribute :first, String
    attribute :middle, String
    attribute :last, String
    attribute :suffix, String
    attribute :vet_ind, String
    attribute :birth_date, String
    attribute :alt_address, String
    attribute :va_file_number, String
    attribute :lives_with_vet, String
    attribute :ever_married_ind, String
    attribute :martl_status_type_cd, String

    def initialize(dependents_application)
      @dependents_application = dependents_application
      @spouse_information = @dependents_application['spouse_information']

      self.attributes = spouse_attributes
    end

    def format_info
      attributes.with_indifferent_access
    end

    def alt_address
      @dependents_application.dig('does_live_with_spouse', 'address')
    end

    def address(marriage_info)
      dependent_address(
        @dependents_application,
        marriage_info['lives_with_vet'],
        marriage_info['alt_address']
      )
    end

    private

    def spouse_attributes
      marriage_info = {
        'ssn': @spouse_information['ssn'],
        'birth_date': @spouse_information['birth_date'],
        'ever_married_ind': 'Y',
        'martl_status_type_cd': marital_status,
        'vet_ind': spouse_is_veteran,
        'lives_with_vet': lives_with_vet,
        'alt_address': alt_address
      }.merge(@spouse_information['full_name']).with_indifferent_access

      marriage_info.merge!({ 'va_file_number': @spouse_information['va_file_number'] }) if spouse_is_veteran == 'Y'

      marriage_info
    end

    def lives_with_vet
      @dependents_application.dig('does_live_with_spouse', 'spouse_does_live_with_veteran')
    end

    def spouse_is_veteran
      @spouse_information['is_veteran'] ? 'Y' : 'N'
    end

    def marital_status
      lives_with_vet ? 'Married' : 'Separated'
    end
  end
end
