
# frozen_string_literal: true

module ClaimsApi
  class Form526
    include ActiveModel::Validations
    include ActiveModel::Conversion
    extend ActiveModel::Naming

    REQUIRED_FIELDS = [
                        :veteran,
                        :claimantCertification,
                        :standardClaim,
                        :applicationExpirationDate,
                        :serviceInformation,
                        :disabilities
                      ]

    NOT_REQUIRED_FIELDS = [
                            :directDeposit,
                            :servicePay,
                            :treatments
                          ]

    (REQUIRED_FIELDS + NOT_REQUIRED_FIELDS).each do |method|
      attr_accessor method.to_sym
    end

    REQUIRED_FIELDS.each do |method|
      validates method.to_sym, presence: true
    end

    def initialize(params = {})
      @attributes = []
      params.each do |name, value|
        @attributes << name.to_sym
        begin
          send("#{name}=", value)
        rescue StandardError
          raise "#{name} is not a valid attribute"
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
      raise errors.messages.to_s unless valid?
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
