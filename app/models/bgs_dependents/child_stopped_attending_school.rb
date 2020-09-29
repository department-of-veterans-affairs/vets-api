# frozen_string_literal: true

module BGSDependents
  class ChildStoppedAttendingSchool < Base
    def initialize(child_info)
      @child_info = child_info
    end

    def format_info
      {
        event_date: @child_info['date_child_left_school'],
        ssn: @child_info['ssn'],
        birth_date: @child_info['birth_date']
      }.merge(@child_info['full_name']).with_indifferent_access
    end
  end
end
