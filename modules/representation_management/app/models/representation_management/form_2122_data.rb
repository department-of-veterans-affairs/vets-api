# frozen_string_literal: true

module RepresentationManagement
  class Form2122Data < RepresentationManagement::Form2122Base
    attr_accessor :organization_id

    validates :organization_id, presence: true
    validate :organization_exists?

    def organization
      @organization ||= find_organization
    end

    private

    def find_organization
      AccreditedOrganization.find_by(id: organization_id) ||
        Veteran::Service::Organization.find_by(poa: organization_id)
    end

    def organization_exists?
      return unless organization.nil?

      errors.add(:organization, 'Organization not found')
    end
  end
end
