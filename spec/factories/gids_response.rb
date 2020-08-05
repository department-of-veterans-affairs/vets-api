# frozen_string_literal: true

FactoryBot.define do
  factory :gids_response, class: GI::GIDSResponse do
    status { 200 }
    body {
      {
        data:
        {
          attributes: {
            name: 'School Name',
            city: 'Test',
            state: 'TN',
            versioned_school_certifying_officials: [
              {
                priority: 'Primary',
                email: 'test@edu_sample.com'
              },
              {
                priority: 'Secondary',
                email: 'test@edu_sample.com'
              }
            ]
          }
        }
      }
    }

    trait :empty do
      body {
        {
          data: {
            attributes: {}
          }
        }
      }
    end

    trait :no_scos do
      body {
        {
          data: {
            attributes: {
              name: 'School Name',
              city: 'Test',
              state: 'TN',
              versioned_school_certifying_officials: []
            }
          }
        }
      }
    end
  end
end
