# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class ClaimEstablisher
    include Sidekiq::Worker

    # parameter will probably be named something else
    # once that model gets made

    def perform(auto_claim_id)
      auto_claim = ClaimsApi::AutoEstablishedClaim.find(auto_claim_id)
      ## Get model persumably that model contrains the form attrs
      form_data = auto_claim.form.to_internal

      ## Not sure if we'll store these auth headers on the model as well
      # or if that'll come in through parameters to the worker
      auth_headers = auto_claim.auth_headers_encrypted

      response = service(auth_headers).submit_form526(form_data)

      auto_claim.evss_id = response.claim_id
      auto_claim.status = ClaimsApi::AutoEstablishedClaim::SUCCESS
      auto_claim.save
    end

    private

    def service(auth_headers)
      EVSS::DisabilityCompensationForm::ServiceAllClaim.new(
        auth_headers
      )
    end
  end
end
