# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  class AppointmentSerializer
    include FastJsonapi::ObjectSerializer
    attributes :message
  end
end
