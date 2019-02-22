
# frozen_string_literal: true

module ClaimsApi
  class Form526
    include ActiveModel::Validations
    include ActiveModel::Serialization
    include ActiveModel::Conversion
    extend ActiveModel::Naming

    attr_accessor :veteran,
                  :claimantCertification,
                  :standardClaim,
                  :applicationExpirationDate,
                  :serviceInformation,
                  :disabilities,
                  :directDeposit,
                  :servicePay,
                  :treatments

    validates :veteran, presence: true
    validates :claimantCertification, presence: true
    validates :applicationExpirationDate, presence: true
    validates :serviceInformation, presence: true
    validates :disabilities, presence: true

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
