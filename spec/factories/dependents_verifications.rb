# frozen_string_literal: true

FactoryBot.define do
  factory :dependent_verifications, class: Hash do
    skip_create

    dependency_decs { build_list(:dependency_dec, 1) }
    diaries { build_list(:diary_entry, 1) }

    trait :multiple_entries do
      diaries { build_list(:diary_entry, 2) }
    end

    trait :no_entries do
      diaries { [] }
    end

    trait :status_type_cxcl do
      diaries { build_list(:diary_entry, 1, diary_lc_status_type: 'CXCL') }
    end

    trait :due_in_7_years do
      diaries { build_list(:diary_entry, 1, diary_due_date: 7.years.from_now) }
    end

    trait :due_in_7_years_1_day do
      diaries { build_list(:diary_entry, 1, diary_due_date: 7.years.from_now + 1.day) }
    end

    initialize_with { attributes }
  end

  factory :dependency_dec, class: Hash do
    skip_create

    award_effective_date { DateTime.new(2015, 4, 1) }
    award_event_id { '182090' }
    award_type { 'CPL' }
    begin_award_event_id { '182033' }
    beneficiary_id { '600061742' }
    birthday_date { DateTime.new(2015, 3, 24) }
    decision_date { DateTime.new(2018, 9, 20, 10, 29, 48) }
    decision_id { '226058' }
    dependency_decision_id { '81255' }
    dependency_decision_type { 'EMC' }
    dependency_decision_type_description { 'Eligible Minor Child' }
    dependency_status_type { 'MC' }
    dependency_status_type_description { 'Minor Child' }
    deprecated_date { DateTime.new(2018, 9, 20, 16, 10, 23) }
    end_award_event_id { '182090' }
    event_date { DateTime.new(2015, 3, 24) }
    first_name { 'WES' }
    full_name { 'WES FORD' }
    last_name { 'FORD' }
    modified_action { 'U' }
    modified_by { 'VBACOREEHEE' }
    modified_date { DateTime.new(2018, 9, 20, 16, 10, 23) }
    modified_location { '317' }
    modified_process { 'Awds/RBA-cp_dependdec_pkg.do_upd' }
    person_id { '600240138' }
    social_security_number { '796822829' }
    sort_date { DateTime.new(2018, 9, 20, 10, 29, 48) }
    sort_order_number { '0' }
    veteran_id { '600061742' }
    veteran_indicator { 'N' }

    initialize_with { attributes }
  end

  factory :diary_entry, class: Hash do
    skip_create

    diary_lc_status_type { 'PEND' }
    diary_reason_type { '24' }
    diary_due_date { 6.years.from_now }

    initialize_with { attributes }
  end
end
