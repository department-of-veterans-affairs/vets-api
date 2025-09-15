# frozen_string_literal: true

module VRE
  module Ch31Eligibility
    class Response
      include Vets::Model
      include Common::Client::Concerns::ServiceStatus

      attribute :veteran_profile, VeteranProfile
      attribute :disability_rating, DisabilityRating
      attribute :irnd_date, String
      attribute :eligibility_termination_date, String
      attribute :entitlement_details, EntitlementDetails
      attribute :res_case_id, Integer
      attribute :res_eligibility_recommendation, String

      def initialize(_status, response = nil)
        if response
          attributes = response.body.deep_transform_keys!(&:underscore)
          super(attributes)
        end
      end
    end
  end
end
