# frozen_string_literal: true

module RepresentationManagement
  class Form2122Data < RepresentationManagement::Form2122Base
    attr_accessor :organization_id

    validates :organization_id, presence: true
    validate :organization_exists?

    def organization
      @organization ||= find_organization
    end

    def limitations_of_consent_checkbox(key)
      # The values of these four checkboxes are unintuitive.  Our online form experience asks the user to select
      # what details to share with the representative but the actual 21-22 form asks the user to select what
      # details to withhold from the representative.  So we need to invert the values.
      # See https://github.com/department-of-veterans-affairs/va.gov-team/issues/98295
      check_consent_limit_boxes = record_consent && consent_limits.any?
      return 0 if check_consent_limit_boxes == false

      consent_limits.include?(key) ? 0 : 1
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
