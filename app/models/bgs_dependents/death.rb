# frozen_string_literal: true

module BGSDependents
  class Death < Base
    def initialize(death_info)
      @death_info = death_info
    end

    def format_info
      {
        'death_date': @death_info['date'],
        'ssn': @death_info['ssn'],
        'birth_date': @death_info['birth_date'],
        'vet_ind': 'N'
      }.merge(@death_info['full_name']).with_indifferent_access
    end
  end
end
