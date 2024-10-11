# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  class BaseController < ::ApplicationController
    include AppointmentAuthorization
    service_tag 'mhv-appointments'
  end
end
