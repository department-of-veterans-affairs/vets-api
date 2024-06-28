# frozen_string_literal: true

class ClaimStatusSerializer
  include JSONAPI::Serializer

  set_id { '' }

  attributes :claimant_id, :claim_service_id, :claim_status, :received_date
end
