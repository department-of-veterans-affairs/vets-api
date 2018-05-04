# frozen_string_literal: true

module Swagger
  module Schemas
    class SubmitDisabilityForm
      include Swagger::Blocks

      swagger_schema :SubmitDisabilityForm do
        key :required, [:data]

        property :data, type: :object do
          property :attributes, type: :object do
            key :required, %i[claim_id end_product_claim_code end_product_claim_name inflight_document_id]
            property :claim_id, type: :integer, example: -6_820_564_985_530_150_012
            property :end_product_claim_code, type: :string, example: '400SUPP'
            property :end_product_claim_name, type: :string, example: '400-eBenefits-Supplemental'
            property :inflight_document_id, type: :integer, example: -7_166_975_058_082_066_996
          end
          property :id, type: :string, example: nil
          property :type, type: :string, example: 'evss_disability_compensation_form_form_submit_response'
        end
      end
    end
  end
end
