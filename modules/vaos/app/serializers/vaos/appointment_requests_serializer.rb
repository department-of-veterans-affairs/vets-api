# frozen_string_literal: true

module VAOS
  class AppointmentRequestsSerializer
    include FastJsonapi::ObjectSerializer

    set_id(&:appointment_request_id)

    set_type :appointment_requests

    attribute :facility do |object|
      object.facility.reverse_merge(type: nil, address: nil).except(:link, :object_type)
    end

    attribute :patient do |object|
      object.patient.slice(:inpatient, :text_messaging_allowed)
    end

    attribute :appointment_request_detail_code do |object|
      Array.wrap(object.appointment_request_detail_code).map do |element|
        element.slice(:appointment_request_detail_code_id, :created_date)
               .merge(detail_code: element[:detail_code].slice(:code, :provider_message, :veteran_message))
      end
    end

    attributes :last_updated_at,
               :created_date,
               :appointment_date,
               :appointment_time,
               :option_date1,
               :option_time1,
               :option_date2,
               :option_time2,
               :option_date3,
               :option_time3,
               :status,
               :appointment_type,
               :visit_type,
               :email,
               :text_messaging_allowed,
               :phone_number,
               :purpose_of_visit,
               :provider_id,
               :second_request,
               :second_request_submitted,
               :best_timeto_call,
               :has_veteran_new_message,
               :has_provider_new_message,
               :provider_seen_appointment_request,
               :requested_phone_call,
               :booked_appt_date_time,
               :type_of_care_id,
               :friendly_location_name,
               :cc_appointment_request,
               :date,
               :assigning_authority
  end
end
