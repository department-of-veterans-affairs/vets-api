# frozen_string_literal: true

module CheckIn
  class ApplicationController < ::ApplicationController
    before_action :check_flipper
    skip_before_action :authenticate
    skip_before_action :verify_authenticity_token

    protected

    def check_flipper
      routing_error unless Flipper.enabled?(:check_in_experience_enabled)
    end
  end
end
