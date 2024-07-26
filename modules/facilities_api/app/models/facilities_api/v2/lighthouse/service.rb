# frozen_string_literal: true

require 'common/models/base'

module FacilitiesApi
  class V2::Lighthouse::Service < Common::Base
    include ActiveModel::Serializers::JSON

    attribute :service, String
    attribute :service_id, String
    attribute :service_type, String
    attribute :new, Float
    attribute :established, Float
    attribute :effective_date, String
    # appointmentLeadIn, String # (not used in frontend)
    # appointmentPhones, Array # (not used in frontend)
    # serviceLocations, Array # (not used in frontend)

    def initialize(svc)
      super(svc)
      self.service = svc['serviceInfo']['name'] if svc['serviceInfo']['name']
      self.service_id = svc['serviceInfo']['serviceId'] if svc['serviceInfo']['serviceId']
      self.service_type = svc['serviceInfo']['serviceType'] if svc['serviceInfo']['serviceType']
      if svc['waitTime']
        self.new = svc['waitTime']['new']
        self.established = svc['waitTime']['established']
        self.effective_date = svc['waitTime']['effectiveDate']
      end
    end
  end
end
