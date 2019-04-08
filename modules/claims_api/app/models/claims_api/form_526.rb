# frozen_string_literal: true

module ClaimsApi
  class Form526
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend ActiveModel::Naming

    DATE_PATTERN = /^(\d{4}|XXXX)-(0[1-9]|1[0-2]|XX)-(0[1-9]|[1-2][0-9]|3[0-1]|XX)$/
    ADDRESS_PATTERN = /^([-a-zA-Z0-9'.,&#]([-a-zA-Z0-9'.,&# ])?)+$/
    CITY_PATTERN = /^([-a-zA-Z0-9'.#]([-a-zA-Z0-9'.# ])?)+$/
    ROUTING_NUMBER_PATTERN = /^\d{9}$/

    REQUIRED_FIELDS = %i[
      veteran
      applicationExpirationDate
      serviceInformation
      disabilities
    ].freeze

    BOOLEAN_REQUIRED_FIELDS = %i[
      claimantCertification
      standardClaim
    ].freeze

    OPTIONAL_FIELDS = %i[
      directDeposit
      servicePay
      treatments
    ].freeze

    ALL_FIELDS = (REQUIRED_FIELDS + OPTIONAL_FIELDS + BOOLEAN_REQUIRED_FIELDS).freeze

    ALL_FIELDS.each do |field|
      attr_accessor field.to_sym
    end

    REQUIRED_FIELDS.each do |field|
      validates field.to_sym, presence: true
    end

    BOOLEAN_REQUIRED_FIELDS.each do |field|
      validates field.to_sym, inclusion: { in: [true, false, 'true', 'false'] }
    end

    validate :validate_nested_inputs

    def initialize(params = {})
      sanitized_params = sanitize_fields(params)
      sanitized_params.each do |name, value|
        send("#{name}=", value)
      end
    end

    def sanitize_fields(params)
      bad_fields = params.keys.to_a - ALL_FIELDS.map(&:to_sym)
      params.delete_if { |k, _v| bad_fields.include?(k) }
      params
    end

    def persisted?
      false
    end

    def attributes
      ALL_FIELDS.map { |method| { method => send(method) } }.reduce(:merge).delete_if { |_k, v| v.blank? }
    end

    def to_internal
      raise cleaned_errors unless valid?
      {
        "form526": attributes,
        "form526_uploads": [],
        "form4142": nil,
        "form0781": nil,
        "form8940": nil
      }.to_json
    end

    def current_mailing_address
      veteran[:currentMailingAddress]
    end

    private

    def cleaned_errors
      errors.messages.map { |key, value| "#{key} " + value.join(' and ') }.join(', ')
    end

    def validate_nested_inputs
      validate_veteran
      validate_service_information
      validate_disabilities
      validate_direct_deposit if directDeposit.present?
      validate_treaments if treatments.present?
    end

    def validate_veteran
      key = current_mailing_address
      errors.add(:veteran, 'must include currentMailingAddress') unless veteran.key?(:currentMailingAddress)
      errors.add(:currentMailingAddress, 'currentMailingAddress is not an object') unless key.is_a?(Hash)
      validate_current_mailing_address unless errors[:currentMailingAddress].any?
    end

    def validate_current_mailing_address
      keys = %i[addressLine1 city state zipFirstFive country type]
      validate_keys_set(keys: keys, parent: current_mailing_address, error_label: 'currentMailingAddress')

      %i[addressLine1 addressLine2].each do |line|
        if invalid?(current_mailing_address, line, ADDRESS_PATTERN)
          errors.add(:currentMailingAddress, "#{line} isn't valid")
        end
      end

      errors.add(:currentMailingAddress, "city isn't valid") if invalid?(current_mailing_address, :city, CITY_PATTERN)
    end

    def validate_direct_deposit
      keys = %i[accountType accountNumber routingNumber]
      validate_keys_set(keys: keys, parent: directDeposit, error_label: 'directDeposit')

      unless %w[Checking Saving].include? directDeposit[:accountType]
        errors.add('directDeposit', 'accountType must be in [Checking, Saving]')
      end

      unless directDeposit[:accountNumber].size >= 4 && directDeposit[:accountNumber].size <= 17
        errors.add('directDeposit', 'accountNumber must be between 4 and 17 characters')
      end

      unless directDeposit[:routingNumber] =~ ROUTING_NUMBER_PATTERN
        errors.add('directDeposit', "routingNumber isn't valid")
      end

      errors.add('directDeposit', 'bankName must be less than 36 characters') unless directDeposit[:bankName].size <= 35
    end

    def validate_keys_set(keys:, parent:, error_label:)
      keys.each do |key|
        errors.add(error_label, "must include #{key}") unless parent.key?(key)
      end
    end

    def validate_service_information
      key = :serviceInformation
      errors.add(key, 'must include servicePeriods') unless serviceInformation.key?(:servicePeriods)
      errors.add(key, 'must include at least 1 servicePeriod') if serviceInformation[:servicePeriods].empty?
      serviceInformation[:servicePeriods].each do |service_period|
        keys = %i[serviceBranch activeDutyBeginDate activeDutyEndDate]
        validate_keys_set(keys: keys, parent: service_period, error_label: 'servicePeriods')

        %i[activeDutyBeginDate activeDutyEndDate].each do |date|
          errors.add('servicePeriods', "#{date} isn't a valid format") if invalid?(service_period, date, DATE_PATTERN)
        end
      end
    end

    def validate_disabilities
      disabilities.each do |disability|
        keys = %i[name disabilityActionType]
        validate_keys_set(keys: keys, parent: disability, error_label: 'disabilities')
      end
    end

    def validate_treatments
      errors.add('treatments', 'Too many treatedDisabilityNames') unless treatments[:treatedDisabilityNames].size <= 100
      %i[startDate endDate].each do |date|
        errors.add('treatments', "#{date} isn't a valid format") unless date =~ DATE_PATTERN
      end
    end

    def invalid?(hash, key, pattern)
      hash[key] && hash[key] !~ pattern
    end
  end
end
