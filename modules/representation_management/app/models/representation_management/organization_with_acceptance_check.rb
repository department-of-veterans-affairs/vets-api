# frozen_string_literal: true

module RepresentationManagement
  class OrganizationWithAcceptanceCheck < SimpleDelegator
    def can_accept_digital_poa_requests
      return false unless __getobj__.can_accept_digital_poa_requests

      Veteran::Service::OrganizationRepresentative.active
                                                  .exists?(organization_poa: __getobj__.poa,
                                                           acceptance_mode: 'any_request')
    end
  end
end
