# frozen_string_literal: true

module AppealsApi
  class ApplicationController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    skip_before_action :set_tags_and_extra_context, raise: false
    before_action :deactivate_endpoint

    def render_response(response)
      render json: response.body, status: response.status
    end

    def deactivate_endpoint
      return unless sunset_date

      if sunset_date.today? || sunset_date.past?
        render json: {
          errors: [
            {
              title: 'Not found',
              detail: "There are no routes matching your request: #{request.path}",
              code: '411',
              status: '404'
            }
          ]
        }, status: :not_found
      end
    end

    def sunset_date
      nil
    end
  end
end
