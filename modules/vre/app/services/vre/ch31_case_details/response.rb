# frozen_string_literal: true

module VRE
  module Ch31CaseDetails
    class Response
      include Vets::Model

      attribute :res_case_id, Integer
      attribute :is_transferred_to_cwnrs, Bool
      attribute :is_interrupted, Bool
      attribute :external_status, Hash

      def initialize(_status, response = nil)
        return unless response

        body = response.body
        super(body)
      end
    end
  end
end
