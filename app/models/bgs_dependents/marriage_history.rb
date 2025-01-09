# frozen_string_literal: true

module BGSDependents
  class MarriageHistory < Base
    def initialize(former_spouse)
      @former_spouse = former_spouse
    end

    def format_info
      {
        start_date: @former_spouse['start_date'],
        end_date: @former_spouse['end_date'],
        marriage_country: @former_spouse.dig('start_location', 'location', 'country'),
        marriage_state: @former_spouse.dig('start_location', 'location', 'state'),
        marriage_city: @former_spouse.dig('start_location', 'location', 'city'),
        divorce_country: @former_spouse.dig('end_location', 'location', 'country'),
        divorce_state: @former_spouse.dig('end_location', 'location', 'state'),
        divorce_city: @former_spouse.dig('end_location', 'location', 'city'),
        marriage_termination_type_code: @former_spouse['reason_marriage_ended']
      }.merge(@former_spouse['full_name']).with_indifferent_access
    end
  end
end
