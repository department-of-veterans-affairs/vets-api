# frozen_string_literal: true

module AccreditedRepresentativePortal
  module SavedClaimService
    module Create
      Error = Class.new(RuntimeError)
      WrongAttachmentsError = Class.new(Error)

      class << self
        def perform(
          type:, metadata:, attachment_guids:,
          claimant_representative:
        )
          ##
          # TODO: Return the `SavedClaimClaimantRepresentative` wrapping this?
          #
          type.new.tap do |saved_claim|
            saved_claim.form = metadata.to_json

            ##
            # TODO: More robust (DB) constraints of the invariants expressed in
            # `organize_attachments!`? I.e., number of types & no re-parenting.
            # Ideally something more atomic with no gap between checking and
            # persisting.
            #
            attachments = organize_attachments!(attachment_guids)

            ##
            # Figuring out when to set `form_id` for claim and attachment
            # records, or what they're even used for, is complicated. It might
            # be nice to easily detect distribution of abandoned attachments.
            # But there is a complexity cost of needing these assignments to
            # agree over time, rather than being set at only one final moment.
            #
            saved_claim.form_attachment = attachments[:form]
            saved_claim.form_attachment.form_id = saved_claim.form_id

            attachments[:documentations].each do |attachment|
              saved_claim.persistent_attachments << attachment
            end

            SavedClaimClaimantRepresentative.create!(
              saved_claim:, **claimant_representative.to_h
            )

            SubmitBenefitsIntakeClaimJob.perform_async(
              saved_claim.id
            )
          end

        ##
        # Expose a discrete set of known exceptions. Expose any remaining with a
        # catch-all exception.
        #
        rescue WrongAttachmentsError
          raise
        ##
        # Errors resulting from schema validations of metadata seem like a fair
        # target for exposing distinctly.
        #
        rescue
          raise Error
        end

        def organize_attachments!(guids)
          attachments =
            PersistentAttachment.where(guid: guids).to_a

          ##
          # No re-parenting allowed.
          #
          attachments.none?(&:saved_claim_id) or
            raise WrongAttachmentsError

          groups = attachments.group_by(&:class)
          forms = groups.delete(PersistentAttachments::VAForm).to_a
          documentations = groups.delete(PersistentAttachments::VAFormDocumentation).to_a

          ##
          # Must be 1 form, 0+ documentations, 0 extraneous.
          #
          (forms.one? && groups.empty?) or
            raise WrongAttachmentsError

          {
            form: forms.first,
            documentations:
          }
        end
      end
    end
  end
end
