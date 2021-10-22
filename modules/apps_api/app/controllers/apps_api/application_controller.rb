# frozen_string_literal: true

module AppsApi
  class ApplicationController < ::OpenidApplicationController
    before_action { set_default_format_to_json }

    def set_default_format_to_json
      request.format = :json if params[:format].nil? && request.headers['HTTP_ACCEPT'].nil?
    end

    def set_tags_and_extra_context
      RequestStore.store['additional_request_attributes'] = { 'source' => 'apps_api' }
      Raven.tags_context(source: 'apps_api')
    end
  end
end
