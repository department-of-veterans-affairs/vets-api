# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'

describe Vet360Redis::Cache do
  let(:user) { build :user, :loa3 }
  let(:contact_info) { Vet360Redis::ContactInformation.for_user(user) }

  describe '.invalidate' do
    it 'invalidates the vet360-contact-info-response cache' do
      contact_info.cache(user.uuid, 'cache data')

      expect_any_instance_of(Common::RedisStore).to receive(:destroy)

      Vet360Redis::Cache.invalidate(user)
    end
  end
end
