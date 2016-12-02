module HCA
  module Validations
    module_function

    def date_of_birth(input_dob)
      return '' if !input_dob.is_a?(String) || input_dob.blank?

      parsed_dob = Date.parse(input_dob)
      return '' if parsed_dob.future?

      parsed_dob.strftime('%m/%d/%Y')
    end
  end
end
