# frozen_string_literal: true

module BGSDependents
  class Divorce < Base
    def initialize(divorce_info, is_v2 = false)
      @divorce_info = divorce_info
      @is_v2 = is_v2
    end

    def format_info
      {
        divorce_state: @is_v2 ? @divorce_info.dig('divorce_location', 'location', 'state') : @divorce_info.dig('location', 'state'), # rubocop:disable Layout/LineLength
        divorce_city: @is_v2 ? @divorce_info.dig('divorce_location', 'location', 'city') : @divorce_info.dig('location', 'city'), # rubocop:disable Layout/LineLength
        divorce_country: @is_v2 ? @divorce_info.dig('divorce_location', 'location', 'country') : @divorce_info.dig('location', 'country'), # rubocop:disable Layout/LineLength
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
