# frozen_string_literal: true

require_dependency 'claims_api/concerns/request_logging'

module ClaimsApi
  class ApplicationController < ::OpenidApplicationController
    include ClaimsApi::RequestLogging

    skip_before_action :set_tags_and_extra_context, raise: false
    before_action :verify_mvi

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

    def verify_mvi
      unless target_veteran.mvi_record?
        render json: { errors: [{ detail: 'Not found' }] },
               status: :not_found
      end
    end
  end
end
