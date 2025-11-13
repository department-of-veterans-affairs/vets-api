# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  class BaseController < ::ApplicationController
    include AppointmentAuthorization
    before_action :authorize
    before_action :set_controller_name_for_logging

    service_tag 'mhv-appointments'

    private

    def set_controller_name_for_logging
      RequestStore.store['controller_name'] = self.class.name
    end
  end
end
