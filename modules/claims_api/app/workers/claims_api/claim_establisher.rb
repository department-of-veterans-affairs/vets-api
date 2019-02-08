# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class ClaimEstablisher
    include Sidekiq::Worker

    # parameter will probably be named something else
    # once that model gets made

    def perform(_model_id)
      ## Get model persumably that model contrains the form attrs
      form_data = {}

      ## Not sure if we'll store these auth headers on the model as well
      # or if that'll come in through parameters to the worker
      auth_headers = {}

      response = service(auth_headers).submit_form526(form_data)

      ## Update model with response from evss
      # model.status = blah
      # model.save

      # if there is additional_documentation from the form data
      # we need to handle it somehow after the first claim is made
      handle_supporting_documentation
    end

    private

    def handle_supporting_documentation
      # unsure how we'll pass files in
      files = []
      ClaimsApi::EvssDocumentUploader.perform(files)
    end

    def service(auth_headers)
      EVSS::DisabilityCompensationForm::ServiceAllClaim.new(
        auth_headers
      )
    end
  end
end
