# frozen_string_literal: true

module RepresentationManagement
  class OrganizationWithRepContext < SimpleDelegator
    def initialize(organization, representative:)
      super(organization)
      @representative = representative
    end

    def can_accept_digital_poa_requests
      return false unless __getobj__.can_accept_digital_poa_requests

      Veteran::Service::OrganizationRepresentative.active
        .where(representative_id: @representative.representative_id, organization_poa: __getobj__.poa)
        .where.not(acceptance_mode: 'no_acceptance')
        .exists?
    end
  end
end
