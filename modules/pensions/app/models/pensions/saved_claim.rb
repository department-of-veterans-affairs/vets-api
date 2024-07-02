# frozen_string_literal: true

module Pensions
  class SavedClaim < ::SavedClaim
    self.inheritance_column = :_type_disabled

    has_many :persistent_attachments, inverse_of: :saved_claim, dependent: :destroy
    has_many :form_submissions, dependent: :nullify

    # Run after a claim is saved, this processes any files and workflows that are present
    # and sends them to our internal partners for processing.
    def process_attachments!
      refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
      files = Pensions::PersistentAttachment.where(guid: refs.map(&:confirmationCode))
      files.find_each { |f| f.update(saved_claim_id: id) }

      Pensions::Lighthouse::SubmitBenefitsIntakeClaim.perform_async(id)
    end
  end
end
