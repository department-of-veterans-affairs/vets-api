# frozen_string_literal: true

module Vass
  class ApplicationController < ::ApplicationController
    service_tag 'vass'

    skip_before_action :authenticate

    def cors_preflight
      head :ok
    end

    private

    def render_error(error, status = :bad_request)
      render json: { errors: [{ title: error.message, status: Rack::Utils.status_code(status) }] },
             status:
    end
  end
end
