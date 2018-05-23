# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'

describe Vet360Redis::Cache do
  let(:user) { build :user, :loa3 }
  let(:contact_info) { Vet360Redis::ContactInformation.for_user(user) }

  describe '.invalidate' do
    context 'when user.vet360_contact_info is present' do
      it 'invalidates the vet360-contact-info-response cache' do
        contact_info.cache(user.uuid, 'cache data')

        expect_any_instance_of(Common::RedisStore).to receive(:destroy)

        Vet360Redis::Cache.invalidate(user)
      end
    end

    context 'when user.vet360_contact_info is nil' do
      before do
        allow(user).to receive(:vet360_contact_info).and_return(nil)
      end

      it 'does not call #destroy' do
        expect_any_instance_of(Common::RedisStore).to_not receive(:destroy)

        Vet360Redis::Cache.invalidate(user)
      end

      it 'logs to sentry' do
        expect_any_instance_of(described_class).to receive(:log_message_to_sentry)

        Vet360Redis::Cache.invalidate(user)
      end
    end
  end
end
