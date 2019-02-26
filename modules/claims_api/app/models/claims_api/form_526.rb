
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

    NOT_REQUIRED_FIELDS = %i[
      directDeposit
      servicePay
      treatments
    ].freeze

    (REQUIRED_FIELDS + BOOLEAN_REQUIRED_FIELDS + NOT_REQUIRED_FIELDS).each do |field|
      attr_accessor field.to_sym
    end

    REQUIRED_FIELDS.each do |field|
      validates field.to_sym, presence: true
    end

    BOOLEAN_REQUIRED_FIELDS.each do |field|
      validates field.to_sym, inclusion: { in: [true, false] }
    end

    def initialize(params = {})
      @attributes = []
      params.each do |name, value|
        @attributes << name.to_sym
        begin
          send("#{name}=", value)
        rescue StandardError
          raise Common::Exceptions::ValidationErrors, self
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
      raise Common::Exceptions::ValidationErrors, self unless valid?
      {
        "form526": attributes,
        "form526_uploads": [],
        "form4142": nil,
        "form0781": nil,
        "form8940": nil
      }.to_json
    end
  end
end
