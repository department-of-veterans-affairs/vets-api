# frozen_string_literal: true

FactoryBot.define do
  factory :gi_bill_status_response, class: 'BenefitsEducation::Response' do
    first_name { 'John' }
    last_name { 'Doe' }
    name_suffix { 'Jr' }
    date_of_birth { '1967-06-19T06:00:00Z' }
    va_file_number { '796130115' }
    regional_processing_office { 'Northern Office Boston, MA' }
    eligibility_date { '2005-08-01T04:00:00Z' }
    delimiting_date { '2016-08-01T04:00:00Z' }
    percentage_benefit { 100 }
    original_entitlement { { months: 0, days: 21 } }
    used_entitlement { { months: 0, days: 11 } }
    active_duty { true }
    veteran_is_eligible { true }
    remaining_entitlement { { months: 0, days: 12 } }
    enrollments {
      [{
        begin_date: '2012-11-01T04:00:00.000+00:00',
        end_date: '2012-12-01T05:00:00.000+00:00',
        facility_code: '11902614',
        facility_name: 'Purdue University',
        participant_id: '11170323',
        training_type: 'UNDER_GRAD',
        term_id: nil,
        hour_type: nil,
        full_time_hours: 12,
        full_time_credit_hour_under_grad: nil,
        vacation_day_count: 0,
        on_campus_hours: 12.0,
        online_hours: 0.0,
        yellow_ribbon_amount: 0.0,
        status: 'Approved',
        amendments: [{
          on_campus_hours: 7,
          online_hours: 4,
          yellow_ribbon_amount: 8,
          type: 'CourseDrop',
          status: 'Approved',
          change_effective_date: '2015-11-11T07:25:00Z'
        }]
      }]
    }
    initialize_with { new(status: 200, response: {}) }
  end
end
