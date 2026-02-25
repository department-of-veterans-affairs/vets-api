# frozen_string_literal: true

module VRE
  module Ch31CaseMilestones
    class Response
      include Vets::Model

      attribute :res_case_id, Integer
      attribute :response_message, String

      def initialize(_status, response = nil)
        if response
          body = response.body
          body = body.deep_transform_keys { |key| key.to_s.underscore }
          super(body)
        end
      end
    end
  end
end
