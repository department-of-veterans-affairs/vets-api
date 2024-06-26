# frozen_string_literal: true

class ToeClaimantInfoSerializer
  include JSONAPI::Serializer

  attributes :claimant, :service_data, :toe_sponsors

  set_id { '' }
end
