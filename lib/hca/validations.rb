# frozen_string_literal: true

module HCA
  module Validations
    module_function

    INVALID_SSN_REGEXES = [
      /^\d{3}-?\d{2}-?0{4}$/,
      /1{9}|2{9}|3{9}|4{9}|5{9}|6{9}|7{9}|8{9}|9{9}/,
      /^0{3}-?\d{2}-?\d{4}$/,
      /^\d{3}-?0{2}-?\d{4}$/
    ].freeze

    FUTURE_DISCHARGE_CUTOFF = (Settings.hca.future_discharge_testing ? 730 : 180).days

    def parse_date(date_string)
      return nil if !date_string.is_a?(String) || date_string.blank?

      Date.parse(date_string)
    end

    def valid_discharge_date?(date_string)
      date = parse_date(date_string)
      return false if date.nil?

      cutoff = Time.zone.today + FUTURE_DISCHARGE_CUTOFF
      date <= cutoff
    end

    def discharge_date(date_string)
      parsed_date = parse_date(date_string)
      return '' if parsed_date.blank?

      parsed_date.strftime('%m/%d/%Y')
    end

    def date_of_birth(input_dob)
      parsed_dob = parse_date(input_dob)
      return '' if parsed_dob.blank? || parsed_dob.future?

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

    def validate_name(*, **)
      formatted_name = validate_string(*, **)
      return '' if formatted_name.blank?

      formatted_name.upcase
    end

    def validate_ssn(input_ssn)
      return '' unless input_ssn.is_a?(String)

      validated_ssn = input_ssn.gsub(/\D/, '')

      return '' if validated_ssn.size != 9

      INVALID_SSN_REGEXES.each do |invalid_ssn_regex|
        return '' if invalid_ssn_regex.match?(validated_ssn)
      end

      validated_ssn
    end
  end
end
