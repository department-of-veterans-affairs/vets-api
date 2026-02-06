# frozen_string_literal: true

module VRE
  module Ch31CaseMilestones
    class Response
      include Vets::Model

      attribute :res_case_id, Integer
      attribute :response_message, String

      def initialize(_status, response = nil)
        super(response.body) if response
      end
    end
  end
end
