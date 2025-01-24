# frozen_string_literal: true

module BGSDependents
  class Death < Base
    def initialize(death_info)
      @death_info = death_info
      @is_v2 = Flipper.enabled?(:va_dependents_v2)
    end

    def format_info
      {
        death_date: @is_v2 ? format_date(@death_info['dependent_death_date']) : format_date(@death_info['date']),
        ssn: @death_info['ssn'],
        birth_date: @death_info['birth_date'],
        vet_ind: 'N',
        dependent_income: @is_v2 ? formatted_boolean(@death_info['deceased_dependent_income']) : formatted_boolean(@death_info['dependent_income'])
      }.merge(@death_info['full_name']).with_indifferent_access
    end
  end
end
