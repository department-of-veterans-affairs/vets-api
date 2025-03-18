# frozen_string_literal: true

module RepresentationManagement
  class Form2122DigitalSubmission < RepresentationManagement::Form2122Base
    BLANK_ICN = 'ICN value is missing'
    BLANK_PARTICIPANT_ID = 'Corp Participant ID value is blank'
    DEPENDENT_SUBMITTER = 'must submit as the Veteran for digital Power of Attorney Requests'
    DOES_NOT_ACCEPT_DIGITAL_REQUESTS = 'does not accept digital Power of Attorney Requests'
    NOT_FOUND = 'not found'

    attr_accessor :dependent, :organization_id, :user

    validates :organization_id, presence: true
    validate :organization_exists?
    validate :organization_accepts_digital_poa_requests?
    validate :user_is_submitting_as_veteran?
    validate :user_has_participant_id?
    validate :user_has_icn?

    # The values of these four checkboxes are unintuitive. Our online form experience asks the user to select
    # what details to share with the representative but the actual 21-22 form asks the user to select what
    # details to withhold from the representative.  So we need to invert the values.
    # See https://github.com/department-of-veterans-affairs/va.gov-team/issues/98295
    def normalized_limitations_of_consent
      if record_consent && consent_limits.empty?
        []
      elsif record_consent
        LIMITATIONS_OF_CONSENT.difference(consent_limits)
      else
        LIMITATIONS_OF_CONSENT
      end
    end

    def organization
      return @organization if defined? @organization

      @organization = find_organization
    end

    private

    def find_organization
      AccreditedOrganization.find_by(id: organization_id) ||
        Veteran::Service::Organization.find_by(poa: organization_id)
    end

    def organization_exists?
      return unless organization.nil?

      errors.add(:organization, NOT_FOUND)
    end

    def organization_accepts_digital_poa_requests?
      return if organization&.can_accept_digital_poa_requests

      errors.add(:organization, DOES_NOT_ACCEPT_DIGITAL_REQUESTS)
    end

    def user_is_submitting_as_veteran?
      return unless dependent

      errors.add(:user, DEPENDENT_SUBMITTER)
    end

    def user_has_participant_id?
      return if user.participant_id.present?

      errors.add(:user, BLANK_PARTICIPANT_ID)
    end

    def user_has_icn?
      return if user.icn.present?

      errors.add(:user, BLANK_ICN)
    end
  end
end
