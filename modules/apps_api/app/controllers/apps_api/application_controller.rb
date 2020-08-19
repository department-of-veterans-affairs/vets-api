# frozen_string_literal: true

module AppsApi
  class ApplicationController < ::OpenidApplicationController
    skip_before_action :set_tags_and_extra_content, raise: false

    before_action { set_default_format_to_json }

    def set_default_format_to_json
      request.format = :json if params[:format].nil? && request.headers['HTTP_ACCEPT'].nil?
    end
  end
end
