# frozen_string_literal: true

module VAOS
  class AppointmentRequestsSerializer
    include FastJsonapi::ObjectSerializer

    set_id do |object|
      object.data_identifier[:unique_id]
    end

    set_type :appointment_requests

    attributes :last_updated_at,
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
               :patient,
               :best_timeto_call,
               :appointment_request_detail_code,
               :has_veteran_new_message,
               :has_provider_new_message,
               :provider_seen_appointment_request,
               :requested_phone_call,
               :booked_appt_date_time,
               :type_of_care_id,
               :friendly_location_name,
               :patient_id,
               :appointment_request_id,
               :date,
               :assigning_authority,
               :unique_id,
               :system_id,
               :self_uri,
               :self_link,
               :object_type,
               :link,
               :created_date

     attribute :facility do |object|
      object.facility.reverse_merge(type: nil, address: nil)
     end

   end
end
