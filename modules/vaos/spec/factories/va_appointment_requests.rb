# frozen_string_literal: true

FactoryBot.define do
  factory :va_appointment_request, class: 'VAOS::VAAppointmentRequest' do
    appointment_type  { 'Mental Health' }
    visit_type  { 'Office Visit' }

    facility do
      {
        facility_address: '1201 Broad Block Blvd',
        facility_city: 'Richmond',
        facility_state: 'VA',
        facility_code: '652',
        facility_name: 'Richmond VAMC',
        facility_parent_site_code: '688',
        facility_type: 'VAMC'
      }
    end

    email { 'test@va.gov' }
    phone_number  { '+1 (555) 555-5555 x55.55' }
    option_date1  { 10.days.from_now.to_date }
    option_time1  { 'AM' }
    option_date2  { 12.days.from_now.to_date }
    option_time2  { 'AM' }
    option_date3  { 30.days.from_now.to_date }
    option_time3  { 'AM' }
    best_time_to_call { '9 AM - 11 AM' }
    purpose_of_visit  { 'Other' }
    other_purpose_of_visit  { 'Other purpose of visit' }
    status  { 'Submitted' }
    provider_id { 'PROV1' }
    second_request  { false }
    provider_name { 'zztest stadd01' }
    text_messaging_allowed  { true }
    requested_phone_call  { true }
    type_of_care_id { '502' }
  end
end
