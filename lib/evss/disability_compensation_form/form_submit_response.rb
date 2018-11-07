# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class FormSubmitResponse < EVSS::Response
      attribute :claim_id, Integer
      attribute :inflight_document_id, Integer
      attribute :end_product_claim_code, String
      attribute :end_product_claim_name, String

      def initialize(status, response = nil)
        super(status, response.body) if response
      end
    end
  end
end
