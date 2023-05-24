# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AcceptableVerifiedCredentialAdoptionService do
  let(:service) { AcceptableVerifiedCredentialAdoptionService.new(user) }
  let(:user) { create(:user, :dslogon) }
  let(:user_verification) { create(:dslogon_user_verification, dslogon_uuid: user.edipi) }
  let!(:user_account) { user_verification.user_account }
  let(:statsd_key) { 'api.user_transition_availability' }

  before { allow(StatsD).to receive(:increment) }

  describe '.perform' do
    context 'when Flipper organic_conversion_experiment is enabled' do
      context 'User is dslogon authenticated' do
        context 'When user has avc' do
          let!(:user_acceptable_verified_credential) do
            create(:user_acceptable_verified_credential, :with_avc, user_account:)
          end

          it 'hash returns false' do
            expect(service.perform).to include(organic_modal: false)
          end

          it 'hash returns correct credential type - dslogon' do
            expect(service.perform).to include(credential_type: SAML::User::DSLOGON_CSID)
          end

          it 'does not log attempt' do
            service.perform
            expect(StatsD).to have_received(:increment).exactly(0).times
          end
        end

        context 'When user has ivc' do
          let!(:user_acceptable_verified_credential) do
            create(:user_acceptable_verified_credential, :with_ivc, user_account:)
          end

          it 'hash returns false' do
            expect(service.perform).to include(organic_modal: false)
          end

          it 'hash returns correct credential type - dslogon' do
            expect(service.perform).to include(credential_type: SAML::User::DSLOGON_CSID)
          end

          it 'does not log attempt' do
            service.perform
            expect(StatsD).to have_received(:increment).exactly(0).times
          end
        end

        context 'When user has no avc/ivc' do
          let!(:user_acceptable_verified_credential) do
            create(:user_acceptable_verified_credential, :without_avc_ivc, user_account:)
          end

          it 'hash returns true' do
            expect(service.perform).to include(organic_modal: true)
          end

          it 'hash returns correct credential type - dslogon' do
            expect(service.perform).to include(credential_type: SAML::User::DSLOGON_CSID)
          end

          it 'logs attempt' do
            service.perform
            expect(StatsD).to have_received(:increment).exactly(1).times
            expect(StatsD).to have_received(:increment).with("#{statsd_key}.organic_modal.dslogon").exactly(1).time
          end
        end
      end

      context 'When user is login.gov authenticated' do
        let(:user) { create(:user, :accountable_with_logingov_uuid, authn_context: IAL::LOGIN_GOV_IAL2) }
        let(:user_verification) { create(:logingov_user_verification, logingov_uuid: user.logingov_uuid) }
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :with_avc, user_account:)
        end

        it 'hash returns false' do
          expect(service.perform).to include(organic_modal: false)
        end

        it 'hash returns correct credential type - login.gov' do
          expect(service.perform).to include(credential_type: SAML::User::LOGINGOV_CSID)
        end

        it 'does not log attempt' do
          service.perform
          expect(StatsD).to have_received(:increment).exactly(0).times
        end
      end

      context 'When user is idme authenticated' do
        let(:user) { create(:user, :accountable, authn_context: LOA::IDME_LOA3_VETS) }
        let(:user_verification) { create(:idme_user_verification, idme_uuid: user.idme_uuid) }
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :with_ivc, user_account:)
        end

        it 'hash returns false' do
          expect(service.perform).to include(organic_modal: false)
        end

        it 'hash returns correct credential type - idme' do
          expect(service.perform).to include(credential_type: SAML::User::IDME_CSID)
        end

        it 'does not log attempt' do
          service.perform
          expect(StatsD).to have_received(:increment).exactly(0).times
        end
      end

      context 'User is mhv authenticated' do
        context 'When user has avc' do
          let(:user) { create(:user, :mhv, authn_context: SAML::User::MHV_ORIGINAL_CSID) }
          let(:user_verification) { create(:mhv_user_verification, mhv_uuid: user.mhv_correlation_id) }
          let!(:user_acceptable_verified_credential) do
            create(:user_acceptable_verified_credential, :with_avc, user_account:)
          end

          it 'hash returns false' do
            expect(service.perform).to include(organic_modal: false)
          end

          it 'hash returns correct credential type - mhv' do
            expect(service.perform).to include(credential_type: SAML::User::MHV_ORIGINAL_CSID)
          end

          it 'does not log attempt' do
            service.perform
            expect(StatsD).to have_received(:increment).exactly(0).times
          end
        end
      end

      context 'When user has ivc' do
        let(:user) { create(:user, :mhv, authn_context: SAML::User::MHV_ORIGINAL_CSID) }
        let(:user_verification) { create(:mhv_user_verification, mhv_uuid: user.mhv_correlation_id) }
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :with_ivc, user_account:)
        end

        it 'hash returns false' do
          expect(service.perform).to include(organic_modal: false)
        end

        it 'hash returns correct credential type - mhv' do
          expect(service.perform).to include(credential_type: SAML::User::MHV_ORIGINAL_CSID)
        end

        it 'does not log attempt' do
          service.perform
          expect(StatsD).to have_received(:increment).exactly(0).times
        end
      end

      context 'When user has no avc/ivc' do
        let(:user) { create(:user, :mhv, authn_context: SAML::User::MHV_ORIGINAL_CSID) }
        let(:user_verification) { create(:mhv_user_verification, mhv_uuid: user.mhv_correlation_id) }
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :without_avc_ivc, user_account:)
        end

        it 'hash returns true' do
          expect(service.perform).to include(organic_modal: true)
        end

        it 'hash returns correct credential type - mhv' do
          expect(service.perform).to include(credential_type: SAML::User::MHV_ORIGINAL_CSID)
        end

        it 'logs attempt' do
          service.perform
          expect(StatsD).to have_received(:increment).exactly(1).times
          expect(StatsD).to have_received(:increment).with("#{statsd_key}.organic_modal.mhv").exactly(1).time
        end
      end
    end

    context 'When Flipper organic_conversion_experiment is disabled' do
      before do
        Flipper.disable(:organic_conversion_experiment)
      end

      it 'hash returns false' do
        expect(service.perform).to include(organic_modal: false)
      end

      it 'does not log attempt' do
        service.perform
        expect(StatsD).to have_received(:increment).exactly(0).times
      end
    end
  end
end
