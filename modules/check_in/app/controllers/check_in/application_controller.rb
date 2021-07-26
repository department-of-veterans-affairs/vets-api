# frozen_string_literal: true

module CheckIn
  class ApplicationController < ::ApplicationController
    before_action :authorize
    skip_before_action :authenticate
    skip_before_action :verify_authenticity_token

    protected

    def authorize
      routing_error unless Flipper.enabled?('check_in_experience_enabled', params[:cookie_id])
    end
  end
end
