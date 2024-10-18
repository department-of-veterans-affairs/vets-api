# frozen_string_literal: true

module RepresentationManagement
  class Form2122Data < RepresentationManagement::Form2122Base
    def organization_name
      find_organization_name
    end

    attr_writer :organization_name

    validate :organization_name_resolves?

    private

    def organization_name_resolves?
      return unless find_organization_name.nil?

      errors.add(:organization_name, 'Organization not found')
    end

    def find_organization_name
      org = AccreditedOrganization.find_by(id: @organization_name) ||
            Veteran::Service::Organization.find_by(poa: @organization_name)
      org&.name
    end
  end
end
