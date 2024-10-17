# frozen_string_literal: true

module RepresentationManagement
  class Form2122Data < RepresentationManagement::Form2122Base
    def organization_name
      @organization_name ||= find_organization_name
    end

    attr_writer :organization_name

    validates :organization_name, presence: true # This will actually be an id of an organization

    private

    def find_organization_name
      org = AccreditedOrganization.find_by(id: @organization_name) ||
            Veteran::Service::Organization.find_by(poa: @organization_name)
      org&.name || @organization_name # If the organization is not found, return the original value
    end
  end
end
