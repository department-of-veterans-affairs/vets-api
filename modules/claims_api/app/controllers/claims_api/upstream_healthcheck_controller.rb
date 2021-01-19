# frozen_string_literal: true

module ClaimsApi
  class UpstreamHealthcheckController < ::OkComputer::OkComputerController
    skip_before_action :verify_authenticity_token
    skip_before_action(:authenticate)

    def index
      checks = OkComputer::Registry.all
      checks.run

      respond checks, status_code(checks)
    end
  end
end
