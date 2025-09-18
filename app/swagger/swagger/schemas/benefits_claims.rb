# frozen_string_literal: true

module Swagger
  module Schemas
    class BenefitsClaims
      include Swagger::Blocks

      swagger_schema :EvidenceSubmission do
        property :acknowledgement_date, type: :string
        property :claim_id, type: :integer
        property :created_at, type: :string
        property :delete_date, type: :string
        property :document_type, type: :string
        property :failed_date, type: :string
        property :file_name, type: :string
        property :id, type: :integer
        property :lighthouse_upload, type: :boolean
        property :tracked_item_id, type: :integer
        property :tracked_item_display_name, type: :string
        property :upload_status, type: :string
        property :va_notify_status, type: :string
      end
    end
  end
end
