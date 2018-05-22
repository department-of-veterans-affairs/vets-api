# frozen_string_literal: true

FactoryBot.define do
  factory :person, class: 'Vet360::Models::Person' do
    addresses   [FactoryBot.build(:vet360_address), FactoryBot.build(:vet360_address, :mailing)]
    emails      [FactoryBot.build(:email)]
    # TODO: the telephone factory will not register??
    # telephones  [FactoryBot.build(:telephone)]
    source_date '2018-04-09T11:52:03-06:00'
    created_at  '2017-04-09T11:52:03-06:00'
    updated_at  '2017-04-09T11:52:03-06:00'
    vet360_id '12345'
  end
end
