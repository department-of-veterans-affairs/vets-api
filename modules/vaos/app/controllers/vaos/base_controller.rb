# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  class BaseController < ::ApplicationController
    include AppointmentAuthorization
    alias_method :authorize, :authorize_appointment!

    service_tag 'mhv-appointments'
  end
end
