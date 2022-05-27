# frozen_string_literal: true

module VANotify
  class InProgressForm686c
    def initialize(form_data)
      @form_data = JSON.parse(form_data)
    end

    def first_name
      form_data.dig('veteran_information', 'full_name', 'first')
    end

    private

    attr_reader :form_data
  end
end
