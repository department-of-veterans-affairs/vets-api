# frozen_string_literal: true

module BGSDependents
  class Marriage < Base
    def initialize(dependents_application)
      @dependents_application = dependents_application

      @spouse_information = @dependents_application['spouse_information']
    end

    def format_info
      lives_with_vet = @dependents_application.dig('does_live_with_spouse', 'spouse_does_live_with_veteran')

      marriage_info = {
        'ssn': @spouse_information['ssn'],
        'birth_date': @spouse_information['birth_date'],
        'ever_married_ind': 'Y',
        'martl_status_type_cd': lives_with_vet ? 'Married' : 'Separated',
        'vet_ind': @spouse_information['is_veteran'] ? 'Y' : 'N',
        'lives_with_vet': lives_with_vet,
        'alt_address': alt_address
      }.merge(@spouse_information['full_name']).with_indifferent_access

      if @spouse_information['is_veteran']
        marriage_info.merge!({ 'va_file_number': @spouse_information['va_file_number'] })
      end

      marriage_info
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
  end
end
