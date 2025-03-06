# frozen_string_literal: true

require 'rails_helper'

describe VAProfileRedis::V2::Cache, :skip_vet360 do
  let(:user) { build(:user, :loa3) }

  describe 'ContactInformationServiceV2' do
    before do
      allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(true)
      allow(VAProfile::Configuration::SETTINGS.contact_information).to receive(:cache_enabled).and_return(true)
    end

    describe '.invalidate v2' do
      context 'when user.vet360_contact_info is present' do
        it 'invalidates the va-profile-contact-info-response cache' do
          VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
            VAProfileRedis::V2::ContactInformation.for_user(user)
          end
          expect(VAProfileRedis::V2::ContactInformation.exists?(user.icn)).to be(true)

          VAProfileRedis::V2::Cache.invalidate(user)

          expect(VAProfileRedis::V2::ContactInformation.exists?(user.icn)).to be(false)
        end
      end

      context 'when user.vet360_contact_info is nil' do
        it 'does not call #destroy' do
          expect_any_instance_of(Common::RedisStore).not_to receive(:destroy)

          VAProfileRedis::V2::Cache.invalidate(user)
        end
      end
    end
  end
end
