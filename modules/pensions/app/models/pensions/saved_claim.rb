# frozen_string_literal: true

module Pensions
  ##
  # Pension 21P-527EZ Active::Record
  # @see app/model/saved_claim
  #
  # todo: migrate encryption to Pensions::SavedClaim, remove inheritance and encrytion shim
  #
  class SavedClaim < ::SavedClaim
    # We want to use the `Type` behavior but we want to override it with our custom type default scope behaviors.
    self.inheritance_column = :_type_disabled

    # We want to override the `Type` behaviors for backwards compatability
    default_scope -> { where(type: 'SavedClaim::Pension') }, all_queries: true

    ##
    # The KMS Encryption Context is preserved from the saved claim model namespace we migrated from
    #
    def kms_encryption_context
      {
        model_name: 'SavedClaim::Pension',
        model_id: id
      }
    end

    # form_id, form_type
    FORM = Pensions::FORM_ID

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
    # utility function to retrieve claimant first name from form
    #
    # @return [String] the claimant first name
    #
    def first_name
      parsed_form.dig('veteranFullName', 'first')
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
