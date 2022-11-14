# frozen_string_literal: true

require 'appeals_api/form_schemas'

module AppealsApi::SupplementalClaims::V0
  class SupplementalClaimsController < AppealsApi::V2::DecisionReviews::SupplementalClaimsController
    include AppealsApi::OpenidAuth

    FORM_NUMBER = '200995_WITH_SHARED_REFS'
    HEADERS = JSON.parse(
      File.read(
        AppealsApi::Engine.root.join('config/schemas/v2/200995_with_shared_refs_headers.json')
      )
    )['definitions']['scCreateParameters']['properties'].keys
  end
end
