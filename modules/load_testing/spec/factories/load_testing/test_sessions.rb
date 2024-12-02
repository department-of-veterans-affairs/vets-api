FactoryBot.define do
  factory :load_testing_test_session, class: 'LoadTesting::TestSession' do
    status { 'pending' }
    concurrent_users { 100 }
    configuration do
      {
        client_id: 'load_test_client',
        type: 'logingov',
        acr: 'http://idmanagement.gov/ns/assurance/ial/2'
      }
    end
  end
end 