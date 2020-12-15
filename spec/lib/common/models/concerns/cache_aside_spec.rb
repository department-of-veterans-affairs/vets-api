# frozen_string_literal: true

require 'rails_helper'
require 'common/models/concerns/cache_aside'

describe Common::CacheAside do
  let(:user) { build :user, :loa3 }
  let(:person) { build :person }

  before do
    allow(Vet360::Models::Person).to receive(:build_from).and_return(person)
  end

  describe '#do_cached_with' do
    let(:person_response) do
      Vet360::ContactInformation::PersonResponse.from(
        OpenStruct.new(status: 200, body: { 'bio' => person.to_hash })
      )
    end

    it 'sets the attributes needed to perform redis actions', :aggregate_failures do
      instance1 = Vet360Redis::ContactInformation.for_user(user)
      instance1.do_cached_with(key: 'test') { person_response }
      expect(instance1.attributes[:uuid]).not_to be(nil)
      expect(instance1.attributes[:response]).not_to be(nil)

      instance2 = Vet360Redis::ContactInformation.for_user(user)
      instance2.do_cached_with(key: 'test') { raise 'value was not cached!' }
      expect(instance2.attributes[:uuid]).not_to be(nil)
      expect(instance2.attributes[:response]).not_to be(nil)
    end
  end
end
