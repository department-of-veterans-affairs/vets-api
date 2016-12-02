module HCA
  module Validations
    module_function

    def date_of_birth(input_dob)
      return '' if !input_dob.is_a?(String) || input_dob.blank?

      parsed_dob = Date.parse(input_dob)
      return '' if parsed_dob.future?

      parsed_dob.strftime('%m/%d/%Y')
    end

    def validate_string(data:, count: nil, nullable: false)
      blank_data = data.blank?

      return if nullable && blank_data
      return '' if blank_data || !data.is_a?(String)

      validated_string = data.dup
      validated_string[0] = validated_string[0].capitalize
      validated_string = validated_string[0, count] unless count.nil?

      validated_string
    end
  end
end
