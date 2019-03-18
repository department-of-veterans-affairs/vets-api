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

    validate :nested_inputs

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

    def nested_inputs
      validate_current_mailing_address
      validate_service_information
      validate_disabilities
      validate_direct_deposit if directDeposit.present?
    end

    def validate_service_information
      errors.add(:base, 'serviceInformation must include servicePeriods') unless serviceInformation.key?(:servicePeriods)
      serviceInformation[:servicePeriods].each do |service_period|
        parent = 'servicePeriod'
        %i[serviceBranch activeDutyBeginDate activeDutyEndDate].each do |required_key|
          errors.add(:servicePeriods, "#{parent} must include #{required_key}") unless service_period.key?(required_key)
        end
      end
    end

    def validate_disabilities
      disabilities.each do |disability|
        %i[name disabilityActionType].each do |required_key|
          errors.add(:disabilities, "must include #{required_key}") unless disability.key?(required_key)
        end
      end
    end

    def validate_current_mailing_address
      %i[addressLine1 city state zipFirstFive country type].each do |required_key|
        errors.add(:currentMailingAddress, "must include #{required_key}") unless veteran[:currentMailingAddress].key?(required_key)
      end
    end

    def validate_direct_deposit
      %i[accountType accountNumber routingNumber].each do |required_key|
        errors.add(:directDeposit, "must include #{required_key}") unless directDeposit.key?(required_key)
      end
    end

    private

    def cleaned_errors
      errors.messages.map { |key, value| "#{key} " + value.join(' and ') }.join(', ')
    end
  end
end
