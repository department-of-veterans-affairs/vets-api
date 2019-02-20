
# frozen_string_literal: true

module ClaimsApi
  class Form526
    include Virtus.model
    extend ActiveModel::Validations

    attribute :veteran, Hash
    attribute :claimantCertification, Hash
    attribute :standardClaim, Hash
    attribute :applicationExpirationDate, Hash
    attribute :serviceInformation, Hash
    attribute :disabilities, Hash

    # validates_presence_of :veteran, 
    #                       :claimantCertification, 
    #                       :standardClaim, 
    #                       :applicationExpirationDate, 
    #                       :serviceInformation, 
    #                       :disabilities

    def to_internal
      {
        "form526": self.attributes,
        "form526_uploads": [],
        "form4142": nil,
        "form0781": nil,
        "form8940": nil
      }.to_json
    end
  end
end
