# frozen_string_literal: true

module Pensions
  class ClaimsBaseController < ::ClaimsBaseController
    before_action :check_flipper_flag

    private

    def check_flipper_flag
      unless Flipper.enabled?(:pension_module_enabled, current_user)
        raise Common::Exceptions::Forbidden
      end
    end
  end
end
