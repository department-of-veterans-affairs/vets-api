
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

    private

    def cleaned_errors
      errors.messages.map { |key, value| "#{key} " + value.join(' and ') }.join(', ')
    end
  end
end
