# frozen_string_literal: true

module AccreditedRepresentativePortal
  module SavedClaim
    class BenefitsIntake < ::SavedClaim
      class << self
        def define_claim(form_id:, business_line:)
          const_set :FORM_ID, form_id
          const_set :BUSINESS_LINE, business_line

          validates! :form_id, inclusion: [form_id]
          after_initialize { self.form_id = self.class::FORM_ID }
        end
      end

      FORM = 'BENEFITS-INTAKE'

      module BusinessLines
        COMPENSATION = 'COMPENSATION'
      end

      with_options inverse_of: :saved_claim, dependent: :destroy do
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

      def business_line
        self.class::BUSINESS_LINE
      end

      class DependencyClaim < self
        define_claim(
          form_id: '21-686C_BENEFITS-INTAKE',
          business_line: BusinessLines::COMPENSATION
        )
      end
    end
  end
end
