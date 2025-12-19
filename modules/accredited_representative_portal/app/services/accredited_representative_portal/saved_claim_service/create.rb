# frozen_string_literal: true

module AccreditedRepresentativePortal
  module SavedClaimService
    module Create
      Error = Class.new(RuntimeError)
      UnknownError = Class.new(Error)
      WrongAttachmentsError = Class.new(Error)
      TooManyRequestsError = Class.new(Error)

      class RecordInvalidError < Error
        attr_reader :record

        def initialize(record)
          @record = record
          message = @record.errors.full_messages.join(', ')
          super(message)
        end
      end

      class << self
        # rubocop:disable Metrics/MethodLength
        def perform(
          type:, metadata:, attachment_guids:,
          claimant_representative:
        )
          SavedClaimClaimantRepresentative.transaction do
            type.new.tap do |saved_claim|
              saved_claim.form = metadata.to_json

              form_id = saved_claim.class::PROPER_FORM_ID
              organize_attachments!(form_id, attachment_guids).tap do |attachments|
                saved_claim.form_attachment = attachments[:form]

                attachments[:documentations].each do |attachment|
                  saved_claim.persistent_attachments << attachment
                end
              end

              # Persist the saved_claim so it has an id. The claimant
              # representative record references saved_claim_id as NOT NULL,
              # so creating the representative before saving the claim would
              # leave saved_claim_id nil and raise PG::NotNullViolation.
              begin
                saved_claim.save!
              rescue ActiveRecord::RecordInvalid => e
                raise RecordInvalidError, e.record
              end

              create!(saved_claim, claimant_representative)

              SubmitBenefitsIntakeClaimJob.new.perform(
                saved_claim.id
              )
            end
          end
        ##
        # Expose a discrete set of known exceptions. Expose any remaining with a
        # catch-all unknown exception.
        #
        rescue RecordInvalidError, WrongAttachmentsError, ::BenefitsIntakeService::Service::InvalidDocumentError
          raise
        rescue Faraday::TooManyRequestsError
          # Faraday raises TooManyRequestsError for 429 responses
          # We are reraising this particular error so vets-website can display a specific message to
          # the user while we continue to have rate-limiting issues
          raise TooManyRequestsError
        rescue Common::Client::Errors::ClientError => e
          if e.message&.match(/429/)
            # Legacy catch for Common::Client 429 errors
            raise TooManyRequestsError
          else
            raise UnknownError
          end
        rescue
          raise UnknownError
        end
        # rubocop:enable Metrics/MethodLength

        private

        def create!(saved_claim, claimant_representative)
          SavedClaimClaimantRepresentative.create!(
            saved_claim:,
            claimant_id:
              claimant_representative.claimant_id,
            accredited_individual_registration_number:
              claimant_representative.accredited_individual_registration_number,
            power_of_attorney_holder_type:
              claimant_representative.power_of_attorney_holder.type,
            power_of_attorney_holder_poa_code:
              claimant_representative.power_of_attorney_holder.poa_code
          )
        rescue ActiveRecord::RecordInvalid => e
          raise RecordInvalidError, e.record
        end

        ##
        # TODO: More robust (DB) constraints of the invariants expressed here?
        # I.e., number of types & no re-parenting. Ideally something more atomic
        # with no gap between checking and persisting.
        #
        def organize_attachments!(form_id, guids) # rubocop:disable Metrics/MethodLength
          groups = Hash.new { |h, k| h[k] = [] }
          attachments = PersistentAttachment.where(guid: guids).to_a

          attachments.each do |attachment|
            attachment.saved_claim_id.blank? or
              raise WrongAttachmentsError, <<~MSG.squish
                This attachment already belongs to a claim
              MSG

            attachment.form_id == form_id or
              raise WrongAttachmentsError, <<~MSG.squish
                This attachment is for the wrong claim type
              MSG

            groups[attachment.class] <<
              attachment
          end

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
