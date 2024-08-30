# frozen_string_literal: true

module Pensions
  ##
  # Pension 21P-527EZ Active::Record
  # @see app/model/saved_claim
  #
  class SavedClaim < ::SavedClaim
    # We want to use the `Type` behavior but we want to override it with our custom type default scope behaviors.
    self.inheritance_column = :_type_disabled

    # We want to override the `Type` behaviors for backwards compatability
    default_scope -> { where(type: 'SavedClaim::Pension') }, all_queries: true

    # form_id, form_type
    FORM = '21P-527EZ'

    ##
    # the predefined regional office address
    #
    # @return [Array<String>] the address lines of the regional office
    #
    def regional_office
      ['Department of Veteran Affairs',
       'Pension Intake Center',
       'P.O. Box 5365',
       'Janesville, Wisconsin 53547-5365']
    end

    ##
    # pension `business line` used in downstream processing
    #
    # @return [String] the defined business line
    #
    def business_line
      'PMC'
    end

    ##
    # claim attachment list
    #
    # @see PersistentAttachment
    #
    # @return [Array<String>] list of attachments
    #
    def attachment_keys
      [:files].freeze
    end

    ##
    # utility function to retrieve claimant email from form
    #
    # @return [String] the claimant email
    #
    def email
      parsed_form['email']
    end

    ##
    # enqueue the sending of the submission confirmation email
    #
    # @see VANotify::EmailJob
    #
    def send_confirmation_email
      return if email.blank?

      VANotify::EmailJob.perform_async(
        email,
        Settings.vanotify.services.va_gov.template_id.form527ez_confirmation_email,
        {
          'first_name' => parsed_form.dig('veteranFullName', 'first')&.upcase.presence,
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
          'confirmation_number' => guid
        }
      )
    end

    ##
    # send this pension claim to the Lighthouse Benefit Intake API
    #
    # @see https://developer.va.gov/explore/api/benefits-intake/docs
    # @see Lighthouse::PensionBenefitIntakeJob
    #
    # @param current_user [User] the current user submitting the form
    #
    def upload_to_lighthouse(current_user = nil)
      refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
      files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
      files.find_each { |f| f.update(saved_claim_id: id) }

      Pensions::PensionBenefitIntakeJob.perform_async(id, current_user&.user_account_uuid)
    end

    ##
    # The KMS Encryption Context is preserved from the saved claim model namespace we migrated from
    #
    def kms_encryption_context
      {
        model_name: 'SavedClaim::Pension',
        model_id: id
      }
    end
  end
end
