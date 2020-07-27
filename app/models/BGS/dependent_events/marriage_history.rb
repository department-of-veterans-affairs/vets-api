# frozen_string_literal: true

module BGS
  module DependentEvents
    class MarriageHistory < BGS::DependentEvents::Base
      def initialize(former_spouse)
        @former_spouse = former_spouse
      end

      def format_info
        {
          'start_date': @former_spouse['start_date'],
          'end_date': @former_spouse['end_date'],
          'marriage_state': @former_spouse.dig('start_location', 'state'),
          'marriage_city': @former_spouse.dig('start_location', 'city'),
          'divorce_state': @former_spouse.dig('start_location', 'state'),
          'divorce_city': @former_spouse.dig('start_location', 'city'),
          'marriage_termination_type_code': @former_spouse['reason_marriage_ended_other']
        }.merge(@former_spouse['full_name']).with_indifferent_access
      end
    end
  end
end
