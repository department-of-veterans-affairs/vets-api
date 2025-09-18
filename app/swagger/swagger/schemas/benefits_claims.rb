# frozen_string_literal: true

module Swagger
  module Schemas
    class BenefitsClaims
      include Swagger::Blocks

      swagger_schema :EvidenceSubmission do
        property :acknowledgement_date, type: :string, nullable: true
        property :claim_id, type: :integer
        property :created_at, type: :string
        property :delete_date, type: :string, nullable: true
        property :document_type, type: :string
        property :failed_date, type: :string, nullable: true
        property :file_name, type: :string
        property :id, type: :integer
        property :lighthouse_upload, type: :boolean
        property :tracked_item_id, type: :integer, nullable: true
        property :tracked_item_display_name, type: :string
        property :upload_status, type: :string
        property :va_notify_status, type: :string, nullable: true
      end
    end
  end
end
