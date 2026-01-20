# frozen_string_literal: true

require 'dependents_benefits/notification_callback'
require 'veteran_facing_services/notification_email/saved_claim'
require 'dependents_benefits/monitor'

module DependentsBenefits
  # @see VeteranFacingServices::NotificationEmail::SavedClaim
  class NotificationEmail < ::VeteranFacingServices::NotificationEmail::SavedClaim
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#new
    def initialize(saved_claim_id, user = nil)
      @va_profile_email = user&.va_profile_email
      @user_first_name = user&.first_name

      super(saved_claim_id, service_name: 'dependents_benefits')
    end

    ##
    # Sends a confirmation email to veteran after claim receipt
    #
    # Determines the appropriate email template based on which forms were submitted
    # (686c, 674, or both) and delivers the confirmation email using VA Notify.
    #
    # @raise [StandardError] If email delivery fails
    # @return [void]
    def send_received_notification
      deliver_status_email_by_claim_type('received', {
                                           FORM_ID => :received_686c_674, # rubocop:disable Naming/VariableNumber
                                           ADD_REMOVE_DEPENDENT => :received_686c_only,
                                           SCHOOL_ATTENDANCE_APPROVAL => :received_674_only
                                         })
    end

    ##
    # Sends an error notification email to veteran after submission failure
    #
    # Determines the appropriate error template based on which forms were submitted
    # (686c, 674, or both) and delivers the error notification email using VA Notify.
    #
    # @raise [StandardError] If email delivery fails
    # @return [void]
    def send_error_notification
      deliver_status_email_by_claim_type('error', {
                                           FORM_ID => :error_686c_674, # rubocop:disable Naming/VariableNumber
                                           ADD_REMOVE_DEPENDENT => :error_686c_only,
                                           SCHOOL_ATTENDANCE_APPROVAL => :error_674_only
                                         })
    end

    ##
    # Sends a submission notification email to veteran after successful submission
    #
    # Determines the appropriate submission template based on which forms were submitted
    # (686c, 674, or both) and delivers the submission notification email using VA Notify.
    #
    # @raise [StandardError] If email delivery fails
    # @return [void]
    def send_submitted_notification
      deliver_status_email_by_claim_type('submitted', {
                                           FORM_ID => :submitted686c674,
                                           ADD_REMOVE_DEPENDENT => :submitted686c_only,
                                           SCHOOL_ATTENDANCE_APPROVAL => :submitted674_only
                                         })
    end

    private

    ##
    # Delivers a status email based on the claim type and form combination
    #
    # @param status [String] The status type for logging purposes (e.g., 'received', 'error', 'submitted')
    # @param claim_type_options [Hash<String, Symbol>] Mapping of claim constants to email template keys:
    #   - FORM_ID: Template key for both 686c and 674 forms
    #   - ADD_REMOVE_DEPENDENT: Template key for 686c only
    #   - SCHOOL_ATTENDANCE_APPROVAL: Template key for 674 only
    # @raise [StandardError] If email delivery fails, logs error to monitor and re-raises
    # @return [void]
    def deliver_status_email_by_claim_type(status, claim_type_options)
      @claim = claim_class.find(saved_claim_id)
      key = if claim.submittable_686? && claim.submittable_674?
              claim_type_options[FORM_ID]
            elsif claim.submittable_686?
              claim_type_options[ADD_REMOVE_DEPENDENT]
            elsif claim.submittable_674?
              claim_type_options[SCHOOL_ATTENDANCE_APPROVAL]
            end
      deliver(key)
    rescue => e
      # we cannot overwrite the monitor used in the base class so create a new one here
      monitor = DependentsBenefits::Monitor.new
      monitor.track_error_event("Error sending #{status} notification email", 'notification_failure',
                                error: e, claim_id: claim.id)
      # NotificationEmail will have monitored this failure.  Is this needed?
      raise e
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#claim_class
    def claim_class
      DependentsBenefits::PrimaryDependencyClaim
    end

    # retrieve the email from the _claim_ or _user_
    def email
      @va_profile_email || claim.parsed_form.dig('dependents_application', 'veteran_contact_information',
                                                 'email_address')
    end

    # assemble details for personalization in the emails
    def personalization
      default = super

      submission_date = claim.submitted_at || Time.zone.today
      vet_info = claim.parsed_form.dig('dependents_application', 'veteran_information') ||
                 claim.parsed_form['veteran_information']
      first_name = @user_first_name || vet_info&.dig('full_name', 'first')
      dependents = {
        'first_name' => first_name&.upcase&.presence,
        'date_submitted' => submission_date.strftime('%B %d, %Y'),
        'confirmation_number' => claim.confirmation_number
      }

      default.merge(dependents)
    end

    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_klass
    def callback_klass
      DependentsBenefits::NotificationCallback.to_s
    end

    # Add 'claim_id' to the metadata for consistency in DataDog and DependentsBenefits::Monitor
    # @see VeteranFacingServices::NotificationEmail::SavedClaim#callback_metadata
    def callback_metadata
      super.merge(claim_id: claim.id)
    end
  end
end
