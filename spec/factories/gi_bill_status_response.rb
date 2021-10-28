# frozen_string_literal: true

FactoryBot.define do
  factory :gi_bill_status_response, class: 'EVSS::GiBillStatus::GiBillStatusResponse' do
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
        amendments: []
      }]
    }
    initialize_with { new(status: 200, response: {}) }
  end
end
