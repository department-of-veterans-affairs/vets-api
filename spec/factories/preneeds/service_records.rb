# frozen_string_literal: true

FactoryBot.define do
  factory :service_record, class: 'Preneeds::ServiceRecord' do
    service_branch { 'AF' } # Air Force
    discharge_type { '1' }
    highest_rank { 'GEN' }
    national_guard_state { 'NY' }

    date_range { attributes_for(:date_range) }
  end
end
