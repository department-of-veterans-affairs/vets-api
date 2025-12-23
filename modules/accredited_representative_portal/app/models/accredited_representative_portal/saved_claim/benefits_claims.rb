# frozen_string_literal: true

module AccreditedRepresentativePortal
  module SavedClaim
    class BenefitsClaims
      class IntentToFile < ::SavedClaim
        FORM_ID = '21-0966'
        FORM = '21-0966'

        # Though ITF submission via Benefits Claims Lighthouse endpoints
        # does not involve a PDF, this is added to maintain compatibility
        # with the claims submissions controller index and serialization.
        with_options(inverse_of: :saved_claim, dependent: :destroy) do
          has_one(
            :form_attachment,
            -> { where(type: 'PersistentAttachments::VAForm') },
            class_name: 'PersistentAttachment'
          )

          has_many(
            :persistent_attachments,
            -> { where(type: 'PersistentAttachments::VAFormDocumentation') }
          )
        end

        validates :form_id, inclusion: [FORM_ID]
        after_initialize do |_saved_claim|
          self.form_id = FORM_ID
        end

        def display_form_id
          self.class::FORM_ID
        end

        def latest_submission_attempt
          OpenStruct.new(aasm_state: 'vbms')
        end

        def pending_submission_attempt_stale?
          false
        end
      end
    end
  end
end
