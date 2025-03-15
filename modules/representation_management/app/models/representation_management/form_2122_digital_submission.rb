# frozen_string_literal: true

module RepresentationManagement
  class Form2122DigitalSubmission < RepresentationManagement::Form2122Base
    BLANK_ICN = 'ICN value is missing'
    BLANK_PARTICIPANT_ID = 'Corp Participant ID value is blank'
    DEPENDENT_SUBMITTER = 'must submit as the Veteran for digital Power of Attorney Requests'
    DOES_NOT_ACCEPT_DIGITAL_REQUESTS = 'does not accept digital Power of Attorney Requests'

    attr_accessor :dependent, :organization_id, :user

    validates :organization_id, presence: true
    validate :organization_exists?
    validate :organization_accepts_digital_poa_requests?
    validate :user_is_submitting_as_veteran?
    validate :user_has_participant_id?
    validate :user_has_icn?

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

    def organization_accepts_digital_poa_requests?
      return if organization.can_accept_digital_poa_requests

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
