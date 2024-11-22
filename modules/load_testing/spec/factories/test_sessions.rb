FactoryBot.define do
  factory :load_testing_test_session, class: 'LoadTesting::TestSession' do
    status { 'pending' }
    concurrent_users { 100 }
    configuration do
      {
        client_id: 'test_client',
        type: 'logingov',
        acr: 'http://idmanagement.gov/ns/assurance/ial/2',
        stages: [
          { duration: '2m', target: 50 },
          { duration: '5m', target: 100 },
          { duration: '2m', target: 0 }
        ]
      }
    end
  end
end 