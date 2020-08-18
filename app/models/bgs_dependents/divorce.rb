# frozen_string_literal: true

module BGSDependents
  class Divorce < Base
    def initialize(divorce_info)
      @divorce_info = divorce_info
    end

    def format_info
      {
        divorce_state: @divorce_info.dig('location', 'state'),
        divorce_city: @divorce_info.dig('location', 'city'),
        divorce_country: @divorce_info.dig('location', 'country')
        marriage_termination_type_code: @divorce_info['reason_marriage_ended'],
        event_dt: @divorce_info['date'],
        vet_ind: 'N',
        type: 'divorce'
      }.merge(@divorce_info['full_name']).with_indifferent_access
    end
  end
end
