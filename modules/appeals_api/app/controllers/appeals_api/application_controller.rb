# frozen_string_literal: true

module AppealsApi
  class ApplicationController < ::ExternalApiApplicationController
    skip_before_action :set_tags_and_extra_context, raise: false

    def render_response(response)
      render json: response.body, status: response.status
    end
  end
end
