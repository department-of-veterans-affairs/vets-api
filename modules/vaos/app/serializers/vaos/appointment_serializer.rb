# frozen_string_literal: true

require 'fast_jsonapi'

module VAOS
  class AppointmentSerializer
    include FastJsonapi::ObjectSerializer

    attributes :facility_id,
      :facility,
      :date_time,
      :reason,
      :type,
      :contact_number,
      :preferred_contact_time,
      :status,
      :pact_team
  end
end
