# frozen_string_literal: true

module BGSDependents
  class StepChild < Base
    EXPENSE_PAID_CONVERTER = { 'Half' => '.5', 'More than half' => '.75', 'Less than half' => '.25' }.freeze
    def initialize(stepchild_info)
      @stepchild_info = stepchild_info
    end

    def format_info
      {
        living_expenses_paid: EXPENSE_PAID_CONVERTER[@stepchild_info['living_expenses_paid']],
        lives_with_relatd_person_ind: 'N',
        ssn: @stepchild_info['ssn'],
        birth_date: @stepchild_info['birth_date']
      }.merge(@stepchild_info['full_name']).with_indifferent_access
    end
  end
end
