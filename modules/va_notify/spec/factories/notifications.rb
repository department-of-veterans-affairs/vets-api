FactoryBot.define do
  factory :notification, class: 'VANotify::Notification' do
    notification_id { SecureRandom.uuid }
    source_location { 'caller' }
    callback { 'SomeClass' }
  end
end
