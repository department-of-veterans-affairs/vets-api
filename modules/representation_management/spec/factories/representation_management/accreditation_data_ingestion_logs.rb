# frozen_string_literal: true

FactoryBot.define do
  factory :accreditation_data_ingestion_log, class: 'RepresentationManagement::AccreditationDataIngestionLog' do
    dataset { :accreditation_api }
    status { :running }
    agents_status { :not_started }
    attorneys_status { :not_started }
    representatives_status { :not_started }
    veteran_service_organizations_status { :not_started }
    started_at { Time.current }
    finished_at { nil }
    metrics { {} }

    trait :trexler_file do
      dataset { :trexler_file }
    end

    trait :completed do
      status { :success }
      agents_status { :success }
      attorneys_status { :success }
      representatives_status { :success }
      veteran_service_organizations_status { :success }
      finished_at { Time.current }
    end

    trait :failed do
      status { :failed }
      finished_at { Time.current }
    end

    trait :with_metrics do
      metrics do
        {
          'agents' => { 'count' => 100 },
          'attorneys' => { 'count' => 200 },
          'representatives' => { 'count' => 300 },
          'veteran_service_organizations' => { 'count' => 50 }
        }
      end
    end
  end
end
