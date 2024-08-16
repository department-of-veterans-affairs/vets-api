# frozen_string_literal: true

require 'rails_helper'
require 'common/models/concerns/cache_aside'

describe Common::CacheAside do
  let(:user) { build :user, :loa3 }
  let(:person) { build :person }

  before do
    allow(VAProfile::Models::Person).to receive(:build_from).and_return(person)
  end

  describe '#do_cached_with' do
    let(:person_response) do
      if Flipper.enabled?(:va_profile_information_v3_redis, user)
        VAProfile::ProfileInformation::PersonResponse.from(
          OpenStruct.new(status: 200, body: { 'bio' => person.to_hash })
        )
      else
        VAProfile::ContactInformation::PersonResponse.from(
          OpenStruct.new(status: 200, body: { 'bio' => person.to_hash })
        )
      end
    end

    it 'sets the attributes needed to perform redis actions', :aggregate_failures do
      if Flipper.enabled?(:va_profile_information_v3_redis, user)
        instance1 = VAProfileRedis::ProfileInformation.for_user(user)
      else
        instance1 = VAProfileRedis::ContactInformation.for_user(user)
      end
      instance1.do_cached_with(key: 'test') { person_response }
      expect(instance1.attributes[:uuid]).not_to be(nil)
      expect(instance1.attributes[:response]).not_to be(nil)

      if Flipper.enabled?(:va_profile_information_v3_redis, user)
        instance2 = VAProfileRedis::ProfileInformation.for_user(user)
      else
        instance2 = VAProfileRedis::ContactInformation.for_user(user)
      end
      instance2.do_cached_with(key: 'test') { raise 'value was not cached!' }
      expect(instance2.attributes[:uuid]).not_to be(nil)
      expect(instance2.attributes[:response]).not_to be(nil)
    end
  end
end
