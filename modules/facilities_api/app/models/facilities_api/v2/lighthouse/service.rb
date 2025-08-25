# frozen_string_literal: true

require 'vets/model'

module FacilitiesApi
  class V2::Lighthouse::Service
    include Vets::Model

    attribute :serviceName, String
    attribute :service, String
    attribute :serviceType, String
    attribute :new, Float
    attribute :established, Float
    attribute :effectiveDate, String
    # appointmentLeadIn, String # (not used in frontend)
    # appointmentPhones, Array # (not used in frontend)
    # serviceLocations, Array # (not used in frontend)

    def initialize(svc)
      # Can't use instance variables in this case because it will
      # cause rubocop linting error (Naming/VariableName)
      self.serviceName = svc['serviceInfo']['name'] if svc['serviceInfo']['name']
      self.service = svc['serviceInfo']['serviceId'] if svc['serviceInfo']['serviceId']
      self.serviceType = svc['serviceInfo']['serviceType'] if svc['serviceInfo']['serviceType']

      if svc['waitTime']
        self.new = svc['waitTime']['new']
        self.established = svc['waitTime']['established']
        self.effectiveDate = svc['waitTime']['effectiveDate']
      end

      super(svc)
    end
  end
end
