# frozen_string_literal: true

FactoryBot.define do
  factory :vye_award, class: 'Vye::Award' do
    cur_award_ind { Vye::Award.cur_award_inds.values.sample }
    award_begin_date { DateTime.now }
    award_end_date { DateTime.now + 1.month }
    training_time { 40 }
    payment_date { DateTime.now }
    monthly_rate { 1000.0 }
    begin_rsn { 'reason' }
    end_rsn { 'reason' }
    type_training { 'type' }
    number_hours { 20 }
    type_hours { 'type' }
  end
end
