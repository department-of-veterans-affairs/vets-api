# frozen_string_literal: true

module ClaimsApi
  module V2
    class PowerOfAttorneySerializer
      include JSONAPI::Serializer

      set_type :claims_api_power_of_attorneys
      set_id :id
      set_key_transform :underscore

      attributes :created_at

      attribute :representative do |object|
        object.representative.deep_transform_keys!(&:underscore)
      end

      # "Uploaded" is an internal-only status indicating that the POA PDF
      # was uploaded to VBMS, but we did not make it to updating BGS.
      # For external consistency, return as "Updated"
      attribute :status do |object|
        if object[:status] == ClaimsApi::PowerOfAttorney::UPLOADED
          ClaimsApi::PowerOfAttorney::UPDATED
        else
          object[:status]
        end
      end

      attribute :errors
      attribute :steps

      private

      def created_at
        object.date_request_accepted
      end
    end
  end
end
