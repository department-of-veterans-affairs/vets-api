# frozen_string_literal: true

require 'claims_api/special_issue_mappers/bgs'

FactoryBot.define do
  factory :claims_veteran, class: 'ClaimsApi::Veteran' do
    ssn { '796111863' }
    first_name { 'abraham' }
    middle_name { nil }
    last_name { 'lincoln' }
    gender { 'M' }
    edipi { '384759483' }
    participant_id { Faker::Number.number(digits: 8) }
    birls_file_number { Faker::Number.number(digits: 10) }
    icn { '123498767V234859' }
    idme_uuid { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
    logingov_uuid { nil }
    uuid { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
    icn_with_aaid { nil }
    search_token { nil }
    mhv_icn { nil }
    pid { nil }
    loa { { current: 3 } }

    after(:build)  { |vet| vet.instance_variable_set(:@mpi, MPIData.for_user(vet)) }
  end

  trait :multiple_participant_ids do
    participant_ids { [veteran.participant_id, Faker::Number.number(digits: 8)] }
  end

  trait :nil_birls_id do
    after(:build) do |vet, _|
      vet.mpi.profile.birls_id = nil
    end
  end
end
