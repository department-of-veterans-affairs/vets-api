# frozen_string_literal: true

module AppealsApi
  class ApplicationController < ::ApplicationController
    skip_before_action :set_tags_and_extra_context, raise: false

    def render_response(resp)
      response.headers = resp.headers
      render json: JSON.parse(resp.body), status: resp.status
    end
  end
end
