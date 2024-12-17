# frozen_string_literal: true

require 'rails_helper'

describe VAProfileRedis::V2::Cache, :skip_vet360 do
  let(:user) { build(:user, :loa3) }

  describe 'ContactInformationServiceV2' do
    before do
<<<<<<< HEAD
      allow(Flipper).to receive(:enabled?).with(:va_v3_contact_information_service, instance_of(User)).and_return(true)
      allow(VAProfile::Configuration::SETTINGS.contact_information).to receive(:cache_enabled).and_return(true)
    end

=======
      Flipper.enable(:va_v3_contact_information_service)
      allow(VAProfile::Configuration::SETTINGS.contact_information).to receive(:cache_enabled).and_return(true)
    end

    after do
      Flipper.disable(:va_v3_contact_information_service)
    end

>>>>>>> ef3c0288176bba86adfb7abaf6e3a2c9bd88c1aa
    describe '.invalidate v2' do
      context 'when user.vet360_contact_info is present' do
        it 'invalidates the va-profile-contact-info-response cache' do
          VCR.use_cassette('va_profile/v2/contact_information/person', VCR::MATCH_EVERYTHING) do
            VAProfileRedis::V2::ContactInformation.for_user(user)
          end
          expect(VAProfileRedis::V2::ContactInformation.exists?(user.uuid)).to eq(true)

          VAProfileRedis::V2::Cache.invalidate(user)

          expect(VAProfileRedis::V2::ContactInformation.exists?(user.uuid)).to eq(false)
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
