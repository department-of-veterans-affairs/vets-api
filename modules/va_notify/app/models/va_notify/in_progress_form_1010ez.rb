# frozen_string_literal: true

module VANotify
  class InProgressForm1010ez
    def initialize(form_data)
      @form_data = JSON.parse(form_data)
    end

    def first_name
      form_data.dig('veteran_full_name', 'first')
    end

    def last_name
      form_data.dig('veteran_full_name', 'last')
    end

    def ssn
      form_data['veteran_social_security_number']
    end

    def birth_date
      form_data['veteran_date_of_birth']
    end

    private

    attr_reader :form_data
  end
end
