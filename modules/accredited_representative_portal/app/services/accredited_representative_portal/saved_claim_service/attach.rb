# frozen_string_literal: true

module AccreditedRepresentativePortal
  module SavedClaimService
    module Attach
      Error = Class.new(RuntimeError)
      InvalidFileError = Class.new(Error)

      class << self
        def perform(file)
          PersistentAttachments::VAFormAttachment.new.tap do |attachment|
            attachment.file = file
            validate_record!(attachment)
            validate_upstream!(attachment)

            attachment.save
          end

        ##
        # Expose a discrete set of known exceptions. Expose any remaining with a
        # catch-all exception.
        #
        rescue InvalidFileError
          raise
        rescue
          raise Error
        end

        private

        def validate_record!(attachment)
          attachment.validate!
        rescue ActiveRecord::RecordInvalid => e
          ##
          # Present `ActiveRecord::RecordInvalid` as an `InvalidFileError` only
          # if `file` is the only attribute in violation (likely(?) due to
          # `shrine` validations).
          #
          e.record.errors.details.keys == [:file] and
            raise InvalidFileError

          raise
        end

        ##
        # Duplicates the validations that run on attachments during ultimate
        # claim submission, less the stamping that is applied first.
        #
        def validate_upstream!(attachment)
          BenefitsIntakeService::Service.new.valid_document?(
            document: attachment.to_pdf
          )
        rescue BenefitsIntakeService::Service::InvalidDocumentError
          raise InvalidFileError
        end
      end
    end
  end
end
