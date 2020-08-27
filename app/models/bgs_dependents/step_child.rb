# frozen_string_literal: true

module BGSDependents
  class StepChild < Base
    def initialize(stepchild_info)
      @stepchild_info = stepchild_info
    end

    def format_info
      {
        'lives_with_relatd_person_ind': 'N'
      }.merge(@stepchild_info['full_name']).with_indifferent_access
    end
  end
end
