# frozen_string_literal: true

module BGSDependents
  class Divorce < Base
    def initialize(divorce_info)
      @divorce_info = divorce_info
      @is_v2 = Flipper.enabled?(:va_dependents_v2)
    end

    def format_info
      {
        divorce_state: @is_v2 ? @divorce_info.dig('divorce_location', 'location', 'state') : @divorce_info.dig('location', 'state'),
        divorce_city: @is_v2 ? @divorce_info.dig('divorce_location', 'location', 'city') : @divorce_info.dig('location', 'city'),
        divorce_country: @is_v2 ? @divorce_info.dig('divorce_location', 'location', 'country') : @divorce_info.dig('location', 'country'),
        marriage_termination_type_code: @divorce_info['reason_marriage_ended'],
        end_date: format_date(@divorce_info['date']),
        vet_ind: 'N',
        ssn: @divorce_info['ssn'],
        birth_date: @divorce_info['birth_date'],
        type: 'divorce',
        spouse_income: @is_v2 ? formatted_boolean(@divorce_info['former_spouse_income']) : formatted_boolean(@divorce_info['spouse_income'])
      }.merge(@divorce_info['full_name']).with_indifferent_access
    end
  end
end
