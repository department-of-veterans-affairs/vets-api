# frozen_string_literal: true

module Pensions
  ##
  # (see ::ClaimsBaseController)
  #
  # PROXY
  #
  class ClaimsBaseController < ::ClaimsBaseController
    before_action :check_flipper_flag

    private

    # is the module handling requests to routes?
    # @see config/routes.rb
    def check_flipper_flag
      raise Common::Exceptions::Forbidden unless Flipper.enabled?(:pension_module_enabled, current_user)
    end
  end
end
