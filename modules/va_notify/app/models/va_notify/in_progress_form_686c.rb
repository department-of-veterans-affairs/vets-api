# frozen_string_literal: true

module VANotify
  class InProgressForm686c
    def initialize(form_data)
      @form_data = JSON.parse(form_data)
    end

    def first_name
      form_data.dig('veteran_information', 'full_name', 'first')
    end

    def last_name
      form_data.dig('veteran_information', 'full_name', 'last')
    end

    def ssn
      form_data.dig('veteran_information', 'ssn')
    end

    def birth_date
      form_data.dig('veteran_information', 'birth_date')
    end

    private

    attr_reader :form_data
  end
end
