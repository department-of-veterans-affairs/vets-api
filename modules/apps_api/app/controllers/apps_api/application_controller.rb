# frozen_string_literal: true

module AppsApi
  class ApplicationController < ::ApplicationController
    service_tag 'lighthouse-apps'
    skip_before_action :verify_authenticity_token
    before_action { set_default_format_to_json }

    def set_default_format_to_json
      request.format = :json if params[:format].nil? && request.headers['HTTP_ACCEPT'].nil?
    end

    def set_sentry_tags_and_extra_context
      RequestStore.store['additional_request_attributes'] = { 'source' => 'apps_api' }
      Sentry.set_tags(source: 'apps_api')
    end
  end
end
