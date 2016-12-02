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

    def validate_name(*args)
      formatted_name = validate_string(*args)
      return '' if formatted_name.blank?
      formatted_name.upcase
    end

    def validate_ssn(input_ssn)
      return '' unless input_ssn.is_a?(String)

      validated_ssn = input_ssn.gsub(/\D/, '')

      if validated_ssn.size != 9 ||
        /^\d{3}-?\d{2}-?0{4}$/.match(validated_ssn) ||
        /1{9}|2{9}|3{9}|4{9}|5{9}|6{9}|7{9}|8{9}|9{9}/.match(validated_ssn) ||
        /^0{3}-?\d{2}-?\d{4}$/.match(validated_ssn) ||
        /^\d{3}-?0{2}-?\d{4}$/.match(validated_ssn)
        return ''
      end

      validated_ssn
    end
  end
end
