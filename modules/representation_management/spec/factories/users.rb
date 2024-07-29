FactoryBot.define do
  factory :representation_management_user, class: 'RepresentationManagement::User' do
    first_name { 'Jane' }
    last_name { 'Doe' }
    city { 'Brooklyn' }
    state { 'NY' }
    postal_code { '11201' }
  end
end
