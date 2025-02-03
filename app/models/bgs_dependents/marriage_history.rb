# frozen_string_literal: true

module BGSDependents
  class MarriageHistory < Base
    def initialize(former_spouse)
      @former_spouse = former_spouse
      @is_v2 = Flipper.enabled?(:va_dependents_v2)
      @start_location_source = @is_v2 ? @former_spouse.dig('start_location', 'location') : @former_spouse.dig('start_location')
      @end_location_source = @is_v2 ? @former_spouse.dig('end_location', 'location') : @former_spouse.dig('end_location')
    end

    def format_info
      {
        start_date: @former_spouse['start_date'],
        end_date: @former_spouse['end_date'],
        marriage_country: @start_location_source.dig('country'),
        marriage_state: @start_location_source.dig('state'),
        marriage_city: @start_location_source.dig('city'),
        divorce_country: @end_location_source.dig('country'),
        divorce_state: @end_location_source.dig('state'),
        divorce_city: @end_location_source.dig('city'),
        marriage_termination_type_code: @former_spouse['reason_marriage_ended']
      }.merge(@former_spouse['full_name']).with_indifferent_access
    end
  end
end
