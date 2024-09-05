# frozen_string_literal: true

module Vye
  class ApplicationController < ::ApplicationController
    include Pundit::Authorization

    service_tag 'verify-your-enrollment'

    rescue_from Pundit::NotAuthorizedError, with: -> { render json: { error: 'Forbidden' }, status: :forbidden }
  end
end
