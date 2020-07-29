# frozen_string_literal: true

module BGSDependents
  class Death
    def initialize(death_info)
      @death_info = death_info
    end

    def format_info
      {
        'death_date': @death_info['date'],
        'vet_ind': 'N'
      }.merge(@death_info['full_name'])
    end
  end
end
