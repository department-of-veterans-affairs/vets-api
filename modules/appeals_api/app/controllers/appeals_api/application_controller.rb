# frozen_string_literal: true

module AppealsApi
  class ApplicationController < ::ApplicationController
    skip_before_action :verify_authenticity_token
    skip_after_action :set_csrf_header
    before_action :deactivate_endpoint
    before_action :set_default_headers

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

    DEFAULT_HEADERS = { 'Content-Language' => 'en-US' }.freeze

    def set_default_headers
      DEFAULT_HEADERS.each { |k, v| response.headers[k] = v }
    end

    def set_tags_and_extra_context
      RequestStore.store['additional_request_attributes'] = { 'source' => 'appeals_api' }
      Raven.tags_context(source: 'appeals_api')
    end

    def model_errors_to_json_api(model)
      errors = model.errors.map do |error|
        tpath = error.options.delete(:error_tpath) || 'common.exceptions.validation_errors'
        data = I18n.t(tpath).deep_merge error.options
        data[:detail] = error.message
        data[:source] = { pointer: error.attribute.to_s } if error.options[:source].blank?
        data.compact # remove nil keys
      end
      { errors: }
    end
  end
end
