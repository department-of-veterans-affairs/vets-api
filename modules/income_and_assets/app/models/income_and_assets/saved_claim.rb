# frozen_string_literal: true

require 'income_and_assets/benefits_intake/benefit_intake_job'

module IncomeAndAssets
  ##
  # IncomeAndAssets 21P-0969 Active::Record
  # @see app/model/saved_claim
  #
  class SavedClaim < ::SavedClaim
    # Income and Assets Form ID
    FORM = IncomeAndAssets::FORM_ID

    # the predefined regional office address
    #
    # @return [Array<String>] the address lines of the regional office
    def regional_office
      ['Department of Veteran Affairs',
       'Pension Intake Center',
       'P.O. Box 5365',
       'Janesville, Wisconsin 53547-5365']
    end

    ##
    # Returns the business line associated with this process
    #
    # @return [String]
    def business_line
      'NCA'
    end

    # Utility function to retrieve claimant email from form
    #
    # @return [String] the claimant email
    def email
      parsed_form['email'] || 'test@example.com' # TODO: update this when we have a real email field
    end

    # Utility function to retrieve veteran first name from form
    #
    # @return [String]
    def veteran_first_name
      parsed_form.dig('veteranFullName', 'first')
    end

    # Utility function to retrieve veteran last name from form
    #
    # @return [String]
    def veteran_last_name
      parsed_form.dig('veteranFullName', 'last')
    end

    # Utility function to retrieve claimant first name from form
    #
    # @return [String]
    def claimant_first_name
      parsed_form.dig('claimantFullName', 'first')
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

    # Run after a claim is saved, this processes any files and workflows that are present
    # and sends them to our internal partners for processing.
    # Only removed Sidekiq call from super
    def process_attachments!
      refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
      files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
      files.find_each { |f| f.update(saved_claim_id: id) }
    end
  end
end
