# frozen_string_literal: true

module BGSDependentsV2
  class ChildMarriage < Base
    def initialize(child_marriage) # rubocop:disable Lint/MissingSuper
      @child_marriage = child_marriage
    end

    def format_info
      {
        event_date: @child_marriage['date_married'],
        ssn: @child_marriage['ssn'],
        birth_date: @child_marriage['birth_date'],
        ever_married_ind: 'Y',
        dependent_income: formatted_boolean(@child_marriage['dependent_income'])
      }.merge(@child_marriage['full_name']).with_indifferent_access
    end
  end
end
