# frozen_string_literal: true

module VANotify
  class InProgressForm1010ez
    def initialize(form_data)
      @form_data = JSON.parse(form_data)
    end

    def first_name
      form_data.dig('veteran_full_name', 'first')
    end

    private

    attr_reader :form_data
  end
end
