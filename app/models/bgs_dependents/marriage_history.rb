# frozen_string_literal: true

module BGSDependents
  class MarriageHistory < Base
    def initialize(former_spouse)
      @former_spouse = former_spouse
      @start_source = @former_spouse.dig('start_location', 'location')
      @end_source = @former_spouse.dig('end_location', 'location')
    end

    def format_info
      {
        start_date: @former_spouse['start_date'],
        end_date: @former_spouse['end_date'],
        marriage_country: @start_source['country'],
        marriage_state: @start_source['state'],
        marriage_city: @start_source['city'],
        divorce_country: @end_source['country'],
        divorce_state: @end_source['state'],
        divorce_city: @end_source['city'],
        marriage_termination_type_code: @former_spouse['reason_marriage_ended']
      }.merge(@former_spouse['full_name']).with_indifferent_access
    end
  end
end
