# frozen_string_literal: true

module VRE
  module Ch31CaseDetails
    class OrientationAppointmentDetails
      include Vets::Model

      attribute :appointment_date_time, String
      attribute :appointment_place, String
    end
  end
end
