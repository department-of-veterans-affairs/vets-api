# frozen_string_literal: true

module RepresentationManagement
  # Adapter for Veteran::Service::Organization to make it compatible with AccreditedOrganization serializer
  class AccreditedOrganizationAdapter
    attr_reader :organization

    delegate :id, :name, :phone, :city, :state, :state_code, :zip_code, :zip_suffix, :can_accept_digital_poa_requests,
             to: :organization

    def initialize(organization)
      @organization = organization
    end

    def poa_code
      organization.poa
    end

    # Support ActiveRecord-style .model_name for serializers
    def self.model_name
      AccreditedOrganization.model_name
    end
  end
end
