# frozen_string_literal: true

module BGS
  module DependentEvents
    class ChildMarriage < BGS::DependentEvents::Base
      def initialize(child_marriage)
        @child_marriage = child_marriage
      end

      def format_info
        {
          'event_date': @child_marriage['date_married']
        }.merge(@child_marriage['full_name']).with_indifferent_access
      end
    end
  end
end
