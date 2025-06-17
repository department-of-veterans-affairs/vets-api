# frozen_string_literal: true

module AccreditedRepresentativePortal
  module SavedClaimService
    module Create
      Error = Class.new(RuntimeError)
      UnknownError = Class.new(Error)
      WrongAttachmentsError = Class.new(Error)

      class RecordInvalidError < Error
        attr_reader :record

        def initialize(record)
          @record = record
          message = @record.errors.full_messages.join(', ')
          super(message)
        end
      end

      class << self
        def perform(
          type:, metadata:, attachment_guids:,
          claimant_representative:
        )
          type.new.tap do |saved_claim|
            saved_claim.form = metadata.to_json

            organize_attachments!(attachment_guids).tap do |attachments|
              saved_claim.form_attachment = attachments[:form]

              attachments[:documentations].each do |attachment|
                saved_claim.persistent_attachments << attachment
              end
            end

            create!(saved_claim, claimant_representative)

            SubmitBenefitsIntakeClaimJob.new.perform(
              saved_claim.id
            )
          end

        ##
        # Expose a discrete set of known exceptions. Expose any remaining with a
        # catch-all unknown exception.
        #
        rescue RecordInvalidError, WrongAttachmentsError
          raise
        rescue
          raise UnknownError
        end

        private

        def create!(saved_claim, claimant_representative)
          SavedClaimClaimantRepresentative.create!(
            saved_claim:, **claimant_representative.to_h
          )
        rescue ActiveRecord::RecordInvalid => e
          raise RecordInvalidError, e.record
        end

        ##
        # TODO: More robust (DB) constraints of the invariants expressed here?
        # I.e., number of types & no re-parenting. Ideally something more atomic
        # with no gap between checking and persisting.
        #
        def organize_attachments!(guids)
          attachments =
            PersistentAttachment.where(guid: guids).to_a

          attachments.none?(&:saved_claim_id) or
            raise WrongAttachmentsError, <<~MSG.squish
              This attachment already belongs to a claim
            MSG

          groups = attachments.group_by(&:class)
          forms = groups.delete(PersistentAttachments::VAForm).to_a
          documentations = groups.delete(PersistentAttachments::VAFormDocumentation).to_a

          (forms.one? && groups.empty?) or
            raise WrongAttachmentsError, <<~MSG
              Must have 1 form, 0+ documentations, 0 extraneous.
            MSG

          {
            form: forms.first,
            documentations:
          }
        end
      end
    end
  end
end
