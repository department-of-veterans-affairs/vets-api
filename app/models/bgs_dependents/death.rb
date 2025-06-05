# frozen_string_literal: true

module BGSDependents
  class Death < Base
    def initialize(death_info)
      @death_info = death_info
      @is_v2 = v2?
    end

    def format_info
      dependent_type = relationship_type(@death_info)
      info = {
        death_date: @is_v2 ? format_date(@death_info['dependent_death_date']) : format_date(@death_info['date']),
        ssn: @death_info['ssn'],
        birth_date: @death_info['birth_date'],
        vet_ind: 'N',
        dependent_income: formatted_boolean(@is_v2 ? @death_info['deceased_dependent_income'] : @death_info['dependent_income']) # rubocop:disable Layout/LineLength
      }
      info['marriage_termination_type_code'] = 'Death' if dependent_type[:family] == 'Spouse'
      info.merge(@death_info['full_name']).with_indifferent_access
    end
  end
end
