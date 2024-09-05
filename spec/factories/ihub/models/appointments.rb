# frozen_string_literal: true

require 'ihub/models/appointment'

FactoryBot.define do
  factory :ihub_models_appointment, class: 'IHub::Models::Appointment' do
    appointment_status_code { nil }
    appointment_status_name { nil }
    assigning_facility { nil }
    clinic_code { '525' }
    clinic_name { 'ZZRECHECK (15MIN)' }
    facility_code { '442' }
    facility_name { 'CHEYENNE VAMC' }
    local_id { '2961007.143' }
    other_information { '' }
    start_time { '1996-10-07T14:30:00' }
    status_code { '2' }
    status_name { 'CHECKED OUT' }
    type_code { '9' }
    type_name { 'REGULAR' }
  end
end
