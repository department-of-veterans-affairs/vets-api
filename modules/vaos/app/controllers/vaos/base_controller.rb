# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  class BaseController < ::ApplicationController
    include AppointmentAuthorization
    before_action :authorize

    service_tag 'mhv-appointments'
  end
end
