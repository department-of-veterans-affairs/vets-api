# frozen_string_literal: true

require 'active_model'
require 'common/models/form'

module VAOS
  class CCAppointmentRequestForm < VAOS::AppointmentRequestForm
    attribute :preferred_state, String
    attribute :preferred_city, String
    attribute :preferred_language, String
    attribute :distance_willing_to_travel, Integer
    attribute :distance_eligible, Boolean
    attribute :office_hours, Array[String]
    attribute :preferred_providers, Array[Hash]
    attribute :city_state, Hash
    attribute :service, String
  end
end
