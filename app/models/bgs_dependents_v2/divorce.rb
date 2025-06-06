# frozen_string_literal: true

module BGSDependentsV2
  class Divorce < Base
    def initialize(divorce_info) # rubocop:disable Lint/MissingSuper
      @divorce_info = divorce_info
    end

    def format_info
      {
        divorce_state: @divorce_info.dig('divorce_location', 'location', 'state'),
        divorce_city: @divorce_info.dig('divorce_location', 'location', 'city'),
        divorce_country: @divorce_info.dig('divorce_location', 'location', 'country'),
        marriage_termination_type_code: @divorce_info['reason_marriage_ended'],
        end_date: format_date(@divorce_info['date']),
        vet_ind: 'N',
        ssn: @divorce_info['ssn'],
        birth_date: @divorce_info['birth_date'],
        type: 'divorce',
        spouse_income: formatted_boolean(@divorce_info['spouse_income'])
      }.merge(@divorce_info['full_name']).with_indifferent_access
    end
  end
end
