# frozen_string_literal: true
module Preneeds
  module Validations
    RANKS_VALIDATE = [
      { param: 'branch_of_service', required: true, reg: /\w{2}/ },
      { param: 'start_date', required: true, reg: /\d{4}-(0[1-9]|1[012])-([012][0-9]|3[01])/ },
      { param: 'end_date', required: true, reg: /\d{4}-(0[1-9]|1[012])-([012][0-9]|3[01])/ }
    ].freeze

    def self.get_military_rank_for_branch_of_service(params)
      missing_fields = []
      invalid_fields = {}

      RANKS_VALIDATE.each do |info|
        name = info[:param]
        value = params[name]

        missing_fields << name if info[:required] && value.blank?
        invalid_fields[name] = value if info[:reg].present? && (value =~ info[:reg]).nil?
      end

      missing_fields_check(missing_fields)
      invalid_fields_check(invalid_fields)
    end

    def self.missing_fields_check(missing_fields)
      return if missing_fields.blank?

      msg = "#{missing_fields.join(',')}: required and must be included in request"

      raise Common::Exceptions::ParameterMissing.new(missing_fields.join(', '), detail: msg)
    end

    def self.invalid_fields_check(invalid_fields)
      return if invalid_fields.blank?

      names = invalid_fields.keys
      values = invalid_fields.values

      raise Common::Exceptions::InvalidFieldValue.new(names.join(', '), values.join(', '))
    end
  end
end
