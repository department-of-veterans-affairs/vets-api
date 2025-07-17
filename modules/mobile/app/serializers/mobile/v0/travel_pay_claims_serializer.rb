# frozen_string_literal: true

module Mobile
  module V0
    class TravelPayClaimsSerializer
      include JSONAPI::Serializer

      set_type :travelPayClaims

      attribute :metadata do |response|
        {
          totalRecordCount: response.total_count,
          pageNumber: response.page_number,
          status: response.claims.length < response.total_count ? 206 : 200
        }
      end

      attribute :data do |response|
        response.claims.map do |claim|
          TravelPayClaimSummarySerializer.new(claim).serializable_hash[:data]
        end
      end
    end
  end
end 