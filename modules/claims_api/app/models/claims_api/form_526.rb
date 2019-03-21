# frozen_string_literal: true

module ClaimsApi
  class Form526
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend ActiveModel::Naming

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

    (REQUIRED_FIELDS + OPTIONAL_FIELDS + BOOLEAN_REQUIRED_FIELDS).each do |field|
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
      @attributes = []
      params.each do |name, value|
        @attributes << name.to_sym
        begin
          send("#{name}=", value)
        rescue StandardError
          errors.add(name, 'is not a valid attribute')
        end
      end
    end

    def persisted?
      false
    end

    def attributes
      @attributes.map { |method| { method => send(method) } }.reduce(:merge)
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
    end

    def validate_direct_deposit
      keys = %i[accountType accountNumber routingNumber]
      validate_keys_set(keys: keys, parent: directDeposit, error_label: 'directDeposit')
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
      end
    end

    def validate_disabilities
      disabilities.each do |disability|
        keys = %i[name disabilityActionType]
        validate_keys_set(keys: keys, parent: disability, error_label: 'disabilities')
      end
    end
  end
end
