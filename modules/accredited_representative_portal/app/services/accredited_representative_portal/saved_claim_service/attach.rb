# frozen_string_literal: true

require 'benefits_intake_service/service'

module AccreditedRepresentativePortal
  module SavedClaimService
    module Attach
      Error = Class.new(RuntimeError)
      UnknownError = Class.new(Error)
      UpstreamInvalidError = Class.new(Error)

      class RecordInvalidError < Error
        attr_reader :record

        def initialize(record)
          @record = record
          message = @record.errors.full_messages.join(', ')
          super(message)
        end
      end

      class << self
        def perform(attachment_klass, file:, form_id:)
          attachment_klass.new.tap do |attachment|
            ##
            # Must assign `form_id` _before_ assigning `file` so that the
            # validations of `file` that occur upon assignment are run relative
            # to the appropriate `form_id`.
            #
            attachment.form_id = form_id
            attachment.file = file

            validate_record!(attachment)
            validate_upstream!(attachment)

            attachment.save
          end

        ##
        # Expose a discrete set of known exceptions. Expose any remaining with a
        # catch-all unknown exception.
        #
        rescue RecordInvalidError, UpstreamInvalidError
          raise
        rescue
          raise UnknownError
        end

        private

        def validate_record!(attachment)
          attachment.validate!
        rescue ActiveRecord::RecordInvalid => e
          raise RecordInvalidError, e.record
        end

        def service
          if Flipper.enabled?(:accredited_representative_portal_lighthouse_api_key)
            ::AccreditedRepresentativePortal::BenefitsIntakeService.new
          else
            ::BenefitsIntakeService::Service.new
          end
        end

        ##
        # Duplicates the validations that run on attachments during ultimate
        # claim submission, less the stamping that is applied first. Should
        # we check the stamped version instead?
        #
        def validate_upstream!(attachment)
          service.valid_document?(
            document: attachment.to_pdf
          )
        rescue ::BenefitsIntakeService::Service::InvalidDocumentError => e
          raise UpstreamInvalidError, e.message
        end
      end
    end
  end
end
