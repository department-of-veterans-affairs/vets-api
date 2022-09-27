# frozen_string_literal: true

module ClaimsApi
  module V2
    module Veterans
      class EvidenceWaiverController < ClaimsApi::V2::ApplicationController
        before_action :verify_access!

        def submit
          render json: { status: 'OK' }
        end
      end
    end
  end
end
