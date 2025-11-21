# frozen_string_literal: true

module RepresentationManagement
  # Adapter to make Veteran::Service::Representative compatible with AccreditedIndividual serializers
  #
  # This adapter wraps a Veteran::Service::Representative record and provides the same interface
  # as AccreditedIndividual, allowing both models to use the same serializer.
  #
  # @example
  #   rep = Veteran::Service::Representative.find('12345')
  #   adapter = VeteranRepresentativeAdapter.new(rep)
  #   serializer = AccreditedIndividuals::IndividualSerializer.new(adapter)
  class VeteranRepresentativeAdapter
    attr_reader :representative

    delegate :id, :first_name, :last_name, :full_name, :phone, :email, :city, :state_code, :zip_code,
             :address_line1, :address_line2, :address_line3, :distance, :lat, :long,
             to: :representative

    def initialize(representative)
      @representative = representative
    end

    # Maps user_type to individual_type
    # Veteran::Service::Representative uses 'attorney', 'claim_agents', 'veteran_service_officer'
    # AccreditedIndividual uses 'attorney', 'claims_agent', 'representative'
    def individual_type
      case representative.user_type
      when 'attorney' then 'attorney'
      when 'claim_agents' then 'claims_agent'
      when 'veteran_service_officer' then 'representative'
      else representative.user_type
      end
    end

    def registration_number
      representative.representative_id
    end

    # Veteran::Service::Representative doesn't have these fields from AccreditedIndividual
    def address_type
      nil
    end

    def country_name
      nil
    end

    def country_code_iso3
      nil
    end

    def province
      nil
    end

    def international_postal_code
      nil
    end

    def zip_suffix
      nil
    end

    def accredited_organizations
      # Map Veteran::Service::Organization to AccreditedOrganization format
      representative.organizations.map do |org|
        AccreditedOrganizationAdapter.new(org)
      end
    end

    # Support ActiveRecord-style .model_name for serializers
    def self.model_name
      AccreditedIndividual.model_name
    end

    # Support pagination in Common::Collection
    def self.max_per_page
      AccreditedRepresentation::Constants::MAX_PER_PAGE
    end
  end

  # Adapter for Veteran::Service::Organization to make it compatible with AccreditedOrganization serializer
  class AccreditedOrganizationAdapter
    attr_reader :organization

    delegate :id, :name, :phone, :state, to: :organization

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
