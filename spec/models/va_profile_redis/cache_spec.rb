# frozen_string_literal: true

require 'rails_helper'

describe VAProfileRedis::Cache, :skip_vet360 do
  let(:user) { build :user, :loa3 }

  describe 'ContactInformationServiceV1' do
    before do
      Flipper.disable(:va_v3_contact_information_service)
      allow(user).to receive(:vet360_id).and_return('1')
      allow(VAProfile::Configuration::SETTINGS.contact_information).to receive(:cache_enabled).and_return(true)
    end

    describe '.invalidate' do
      context 'when user.vet360_contact_info is present' do
        it 'invalidates the va-profile-contact-info-response cache' do
          VCR.use_cassette('va_profile/contact_information/person_full', VCR::MATCH_EVERYTHING) do
            VAProfileRedis::ContactInformation.for_user(user)
          end
          expect(VAProfileRedis::ContactInformation.exists?(user.uuid)).to eq(true)

          VAProfileRedis::Cache.invalidate(user)

          expect(VAProfileRedis::ContactInformation.exists?(user.uuid)).to eq(false)
        end
      end

      context 'when user.vet360_contact_info is nil' do
        it 'does not call #destroy' do
          expect_any_instance_of(Common::RedisStore).not_to receive(:destroy)

          VAProfileRedis::Cache.invalidate(user)
        end
      end
    end
  end

  describe 'ContactInformationServiceV2' do
    before do
      Flipper.enable(:va_v3_contact_information_service)
      allow(user).to receive(:vet360_id).and_return('11111')
      allow(VAProfile::Configuration::SETTINGS.contact_information).to receive(:cache_enabled).and_return(true)
    end

    describe '.invalidate v2' do
      context 'when user.vet360_contact_info is present' do
        it 'invalidates the va-profile-contact-info-response cache' do
          VCR.use_cassette('va_profile/v2/contact_information/person_full', VCR::MATCH_EVERYTHING) do
            VAProfileRedis::ContactInformation.for_user(user)
          end
          expect(VAProfileRedis::ContactInformation.exists?(user.uuid)).to eq(true)

          VAProfileRedis::Cache.invalidate(user)

          expect(VAProfileRedis::ContactInformation.exists?(user.uuid)).to eq(false)
        end
      end

      context 'when user.vet360_contact_info is nil' do
        it 'does not call #destroy' do
          expect_any_instance_of(Common::RedisStore).not_to receive(:destroy)

          VAProfileRedis::Cache.invalidate(user)
        end
      end
    end
  end
end
