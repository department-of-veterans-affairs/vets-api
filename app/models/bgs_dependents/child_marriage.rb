# frozen_string_literal: true

module BGSDependents
  class ChildMarriage < Base
    def initialize(child_marriage)
      @child_marriage = child_marriage
    end

    def format_info
      {
        'event_date': @child_marriage['date_married'],
        'ssn': @child_marriage['ssn'],
        'birth_date': @child_marriage['birth_date']
      }.merge(@child_marriage['full_name']).with_indifferent_access
    end
  end
end
