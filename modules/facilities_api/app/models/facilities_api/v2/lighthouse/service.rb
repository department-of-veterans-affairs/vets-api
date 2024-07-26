# frozen_string_literal: true

require 'common/models/base'

module FacilitiesApi
  class V2::Lighthouse::Service < Common::Base
    include ActiveModel::Serializers::JSON

    attribute :service, String
    attribute :serviceId, String
    attribute :serviceType, String
    attribute :new, Float
    attribute :established, Float
    attribute :effectiveDate, String
    # appointmentLeadIn, String # (not used in frontend)
    # appointmentPhones, Array # (not used in frontend)
    # serviceLocations, Array # (not used in frontend)

    def initialize(svc)
      super(svc)
      self.service = svc['serviceInfo']['name'] if svc['serviceInfo']['name']
      self.serviceId = svc['serviceInfo']['serviceId'] if svc['serviceInfo']['serviceId']
      self.serviceType = svc['serviceInfo']['serviceType'] if svc['serviceInfo']['serviceType']
      if svc['waitTime']
        self.new = svc['waitTime']['new']
        self.established = svc['waitTime']['established']
        self.effectiveDate = svc['waitTime']['effectiveDate']
      end
    end
  end
end
