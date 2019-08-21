# frozen_string_literal: true

require_dependency 'claims_api/concerns/request_logging'
require_dependency 'claims_api/concerns/mvi_verification'

module ClaimsApi
  class ApplicationController < ::OpenidApplicationController
    include ClaimsApi::RequestLogging
    include ClaimsApi::MviVerification

    skip_before_action :set_tags_and_extra_context, raise: false

    private

    def target_veteran(with_gender: false)
      if poa_request?
        vet = ClaimsApi::Veteran.from_headers(request.headers, with_gender: with_gender)
        vet.loa = @current_user.loa if @current_user
        vet
      else
        ClaimsApi::Veteran.from_identity(identity: @current_user)
      end
    end
  end
end
