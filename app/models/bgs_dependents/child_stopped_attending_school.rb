# frozen_string_literal: true

module BGSDependents
  class ChildStoppedAttendingSchool
    def initialize(child_info)
      @child_info = child_info
    end

    def format_info
      {
        event_date: @child_info['date_child_left_school']
      }.merge(@child_info['full_name']).with_indifferent_access
    end
  end
end
