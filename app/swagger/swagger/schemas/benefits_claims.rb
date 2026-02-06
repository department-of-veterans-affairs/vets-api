# frozen_string_literal: true

module Swagger
  module Schemas
    class BenefitsClaims
      include Swagger::Blocks

      swagger_schema :FailedEvidenceSubmission do
        key :description, 'A failed evidence submission record'

        property :acknowledgement_date, type: %i[string null], example: '2023-03-15'
        property :claim_id, type: :integer, example: 600_383_363
        property :created_at, type: :string, example: '2023-03-14T10:30:00Z'
        property :delete_date, type: %i[string null], example: '2023-06-14'
        property :document_type, type: :string, example: 'L023'
        property :failed_date, type: :string, example: '2023-03-14'
        property :file_name, type: :string, example: 'medical_records.pdf'
        property :id, type: :integer, example: 123_45
        property :lighthouse_upload, type: :boolean, example: true
        property :tracked_item_id, type: %i[integer null], example: 395_084
        property :tracked_item_display_name, type: %i[string null], example: '21-4142/21-4142a'
        property :upload_status, type: :string, example: 'FAILED'
        property :va_notify_status, type: %i[string null], example: 'permanent-failure'
      end

      swagger_schema :BenefitsClaimDetail do
        key :description, 'Detailed claim data including tracked items'

        property :id do
          key :type, :string
          key :description, 'Claim ID'
          key :example, '600383363'
        end

        property :type do
          key :type, :string
          key :example, 'claim'
        end

        property :attributes do
          key :type, :object

          property :claimTypeCode, type: %i[string null], example: '020NEW'
          property :claimDate, type: %i[string null], example: '2022-09-27'
          property :claimPhaseDates do
            key :type, :object
            property :phaseChangeDate, type: %i[string null], example: '2022-09-30'
            property :currentPhaseBack, type: :boolean, example: false
            property :latestPhaseType, type: %i[string null], example: 'GATHERING_OF_EVIDENCE'
            property :previousPhases, type: :object
          end
          property :claimType, type: %i[string null], example: 'Compensation'
          property :closeDate, type: %i[string null], example: '2023-05-15'
          property :contentions do
            key :type, :array
            items do
              key :type, :object
              property :name, type: :string, example: 'Tinnitus (New)'
            end
          end
          property :decisionLetterSent, type: :boolean, example: false
          property :developmentLetterSent, type: :boolean, example: true
          property :documentsNeeded, type: :boolean, example: true
          property :endProductCode, type: %i[string null], example: '020'
          property :evidenceWaiverSubmitted5103, type: :boolean, example: false
          property :errors do
            key :type, :array
            items do
              key :type, :object
            end
          end
          property :jurisdiction, type: %i[string null], example: 'National Work Queue'
          property :lighthouseId, type: %i[string null], example: '600383363'
          property :maxEstClaimDate, type: %i[string null], example: '2023-08-14'
          property :minEstClaimDate, type: %i[string null], example: '2023-03-22'
          property :status, type: %i[string null], example: 'EVIDENCE_GATHERING_REVIEW_DECISION'
          property :submitterApplicationCode, type: %i[string null], example: 'VBMS'
          property :submitterRoleCode, type: %i[string null], example: 'VBA'
          property :tempJurisdiction, type: %i[string null], example: 'Louisville, KY'
          property :canUpload, type: :boolean, example: true,
                               description: 'Whether the user can upload documents to this claim'
          property :displayTitle do
            key :type, %i[string null]
            key :description, 'Generated display title for the claim'
            key :example, 'Disability Compensation Claim'
          end
          property :claimTypeBase do
            key :type, %i[string null]
            key :description, 'Base claim type used for title generation'
            key :example, 'Compensation'
          end

          property :supportingDocuments do
            key :type, :array
            items do
              key :$ref, :SupportingDocument
            end
          end

          property :trackedItems do
            key :type, :array
            key :description, 'List of evidence requests (tracked items) for this claim'
            items do
              key :$ref, :TrackedItem
            end
          end

          property :evidenceSubmissions do
            key :type, :array
            key :description, 'List of evidence submissions for this claim'
            items do
              key :$ref, :EvidenceSubmission
            end
          end
        end
      end

      swagger_schema :EvidenceSubmission do
        key :description, 'An evidence submission record for a claim'

        property :acknowledgement_date, type: %i[string null], example: '2023-03-15'
        property :claim_id, type: :integer, example: 600_383_363
        property :created_at, type: :string, example: '2023-03-14T10:30:00Z'
        property :delete_date, type: %i[string null], example: '2023-06-14'
        property :document_type, type: %i[string null], example: 'L023'
        property :failed_date, type: %i[string null], example: '2023-03-14'
        property :file_name, type: %i[string null], example: 'medical_records.pdf'
        property :id, type: :integer, example: 123_45
        property :lighthouse_upload, type: :boolean, example: true
        property :tracked_item_id, type: %i[integer null], example: 395_084
        property :tracked_item_display_name, type: %i[string null], example: '21-4142/21-4142a'
        property :tracked_item_friendly_name, type: %i[string null], example: 'Authorization to disclose information'
        property :upload_status, type: %i[string null], example: 'SUCCESS'
        property :va_notify_status, type: %i[string null], example: 'delivered'
      end

      swagger_schema :SupportingDocument do
        key :description, 'A supporting document uploaded for a claim'

        property :documentId, type: %i[string null], example: '{7AF4C5E0-EBCE-49B2-9544-999ECA2904FD}'
        property :documentTypeLabel, type: %i[string null],
                                     example: 'Medical Treatment Record - Non-Government Facility'
        property :originalFileName, type: %i[string null], example: 'medical_records.pdf'
        property :trackedItemId, type: %i[integer null], example: 360_053
        property :uploadDate, type: %i[string null], example: '2022-10-11'
      end

      swagger_schema :TrackedItem do
        key :description, 'An evidence request (tracked item) for a claim'

        # Core fields from Lighthouse API
        property :id, type: :integer, example: 395_084, description: 'Tracked item ID'
        property :displayName, type: %i[string null], example: '21-4142/21-4142a',
                               description: 'Display name of the tracked item'
        property :description, type: %i[string null],
                               example: 'Please complete and return the enclosed VA Form 21-4142.',
                               description: 'Description of what is needed'
        property :status do
          key :type, %i[string null]
          key :description, 'Current status of the tracked item'
          key :enum, %w[ACCEPTED INITIAL_REVIEW_COMPLETE NEEDED_FROM_YOU NEEDED_FROM_OTHERS
                        NO_LONGER_REQUIRED SUBMITTED_AWAITING_REVIEW]
          key :example, 'NEEDED_FROM_YOU'
        end
        property :overdue, type: :boolean, example: false
        property :requestedDate, type: %i[string null], example: '2023-03-16'
        property :receivedDate, type: %i[string null], example: '2023-03-20'
        property :closedDate, type: %i[string null], example: '2023-03-25'
        property :suspenseDate, type: %i[string null], example: '2023-04-15'
        property :uploaded, type: :boolean, example: true
        property :uploadsAllowed, type: :boolean, example: true

        # Content override fields (enriched by service layer)
        property :friendlyName do
          key :type, %i[string null]
          key :description, 'User-friendly display name for the tracked item'
          key :example, 'Authorization to disclose information'
        end
        property :activityDescription do
          key :type, %i[string null]
          key :description, 'Brief description of why this item is needed'
          key :example, 'We need your permission to request your personal information.'
        end
        property :shortDescription do
          key :type, %i[string null]
          key :description, 'Short description of the tracked item'
          key :example, 'Authorization form for medical records'
        end
        property :supportAliases do
          key :type, :array
          key :description, 'Alternative names or form numbers for this tracked item'
          key :example, ['21-4142/21-4142a']
          items do
            key :type, :string
          end
        end
        property :canUploadFile do
          key :type, :boolean
          key :description, 'Whether the user can upload files for this tracked item'
          key :example, true
        end

        # Structured content fields
        property :longDescription do
          key :type, %i[object null]
          key :description, 'Structured content blocks for detailed description'
          property :blocks do
            key :type, :array
            items do
              key :$ref, :ContentBlock
            end
          end
        end
        property :nextSteps do
          key :type, %i[object null]
          key :description, 'Structured content blocks for next steps'
          property :blocks do
            key :type, :array
            items do
              key :$ref, :ContentBlock
            end
          end
        end
        property :noActionNeeded do
          key :type, :boolean
          key :description, 'Whether no action is needed from the veteran'
          key :example, false
        end
        property :isDBQ do
          key :type, :boolean
          key :description, 'Whether this is a Disability Benefits Questionnaire item'
          key :example, false
        end
        property :isProperNoun do
          key :type, :boolean
          key :description, 'Whether the display name is a proper noun'
          key :example, false
        end
        property :isSensitive do
          key :type, :boolean
          key :description, 'Whether this item contains sensitive information'
          key :example, false
        end
        property :noProvidePrefix do
          key :type, :boolean
          key :description, 'Whether to omit the "Provide" prefix in UI'
          key :example, false
        end
      end

      swagger_schema :ContentBlock do
        key :description, 'A structured content block for rich text display'

        property :type do
          key :type, :string
          key :enum, %w[paragraph list lineBreak]
          key :description, 'The type of content block'
          key :example, 'paragraph'
        end
        property :content do
          key :type, %i[string array]
          key :description, 'The content - can be a string or array of inline elements'
          key :example, 'For your benefits claim, we need your permission to request your personal information.'
        end
        property :style do
          key :type, :string
          key :enum, %w[bullet numbered]
          key :description, 'For list blocks, the list style'
          key :example, 'bullet'
        end
        property :items do
          key :type, :array
          key :description, 'For list blocks, the list items'
          key :example, ['Medical treatments', 'Hospitalizations', 'Outpatient care']
        end
      end
    end
  end
end
