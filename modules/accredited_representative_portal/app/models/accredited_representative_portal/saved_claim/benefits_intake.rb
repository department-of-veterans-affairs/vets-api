# frozen_string_literal: true

module AccreditedRepresentativePortal
  module SavedClaim
    class BenefitsIntake < ::SavedClaim
      class << self
        ##
        # Types of Benefits Intake API claims differ only by the value of a
        # couple attributes. `::define_claim_type` is a narrow & rigid interface
        # for defining new claim types. It discourages bespoke customization and
        # encourages a thoughtful pause in the case that some new requirement
        # presents friction.
        #
        def define_claim_type(form_id:, business_line:)
          Class.new(self) do
            validates! :form_id, inclusion: [form_id]
            after_initialize { self.form_id = form_id }

            define_method(:business_line) do
              business_line
            end
          end
        end
      end

      module BusinessLines
        COMPENSATION = 'COMPENSATION'
      end

      DependencyClaim =
        define_claim_type(
          form_id: '21-686C_BENEFITS-INTAKE',
          business_line: BusinessLines::COMPENSATION
        )

      FORM = 'BENEFITS-INTAKE'

      attachment_association_options = {
        inverse_of: :saved_claim,
        dependent: :destroy
      }

      with_options(attachment_association_options) do
        ##
        # TODO: Add some application-level validation that this claim has _only
        # one_ `form_attachment`?
        #
        has_one(
          :form_attachment,
          -> { where(type: PersistentAttachments::VAForm) },
          class_name: 'PersistentAttachment',
          required: true
        )

        has_many(
          :persistent_attachments,
          -> { where(type: PersistentAttachments::VAFormAttachment) }
        )
      end

      delegate :to_pdf, to: :form_attachment
    end
  end
end
