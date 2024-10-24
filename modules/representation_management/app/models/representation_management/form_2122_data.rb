# frozen_string_literal: true

module RepresentationManagement
  class Form2122Data < RepresentationManagement::Form2122Base
    attr_accessor :organization_id

    validates :organization_id, presence: true
    validate :organization_name_exists?

    def organization_name
      @organization_name ||= find_organization_name
    end

    private

    def find_organization_name
      org = AccreditedOrganization.find_by(id: organization_id) ||
            Veteran::Service::Organization.find_by(poa: organization_id)
      org&.name
    end

    def organization_name_exists?
      return unless organization_name.nil?

      errors.add(:organization_name, 'Organization not found')
    end
  end
end
