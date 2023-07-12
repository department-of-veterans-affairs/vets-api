# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AcceptableVerifiedCredentialAdoptionService do
  let(:service) { AcceptableVerifiedCredentialAdoptionService.new(user) }
  let(:user) { create(:user, :dslogon) }
  let(:user_verification) { create(:dslogon_user_verification, dslogon_uuid: user.edipi) }
  let!(:user_account) { user_verification.user_account }
  let(:statsd_key) { 'api.user_transition_availability' }
  let(:va_notify_log) { 'shared.sidekiq.default.VANotify_EmailJob.enqueue' }
  let(:reactivation_template) { Settings.vanotify.services.va_gov.template_id.login_reactivation_email }

  before { allow(StatsD).to receive(:increment) }

  describe '.perform' do
    context 'when Flipper reactivation_experiment is enabled' do
      context 'User is dslogon authenticated' do
        context 'When user has avc' do
          let!(:user_acceptable_verified_credential) do
            create(:user_acceptable_verified_credential, :with_avc, user_account:)
          end

          it 'sends reactivation email' do
            expect(VANotify::EmailJob).to receive(:perform_async).with(
              user.email,
              reactivation_template,
              {
                'name' => user.first_name,
                'legacy_credential' => 'DS Logon',
                'modern_credential' => 'Login.gov'
              }
            )

            service.perform
          end

          it 'logs attempt' do
            service.perform
            expect(StatsD).to have_received(:increment).with(va_notify_log).exactly(1).times
            expect(StatsD).to have_received(:increment).with("#{statsd_key}.reactivation_email.dslogon").exactly(1).time
          end
        end

        context 'When user has ivc', pending: 'Temporary test to only dsl/avc users' do
          let!(:user_acceptable_verified_credential) do
            create(:user_acceptable_verified_credential, :with_ivc, acceptable_verified_credential_at: nil,
                                                                    user_account:)
          end

          it 'sends reactivation email' do
            expect(VANotify::EmailJob).to receive(:perform_async).with(
              user.email,
              reactivation_template,
              {
                'name' => user.first_name,
                'legacy_credential' => 'DS Logon',
                'modern_credential' => 'ID.me'
              }
            )

            service.perform
          end

          it 'logs attempt' do
            service.perform
            expect(StatsD).to have_received(:increment).with(va_notify_log).exactly(1).times
            expect(StatsD).to have_received(:increment).with("#{statsd_key}.reactivation_email.dslogon").exactly(1).time
          end
        end

        context 'When user has no avc/ivc' do
          let!(:user_acceptable_verified_credential) do
            create(:user_acceptable_verified_credential, :without_avc_ivc, user_account:)
          end

          it 'does not send an email' do
            expect(VANotify::EmailJob).not_to receive(:perform_async)

            service.perform
          end

          it 'does not log attempt' do
            service.perform
            expect(StatsD).to have_received(:increment).exactly(0).times
          end
        end
      end

      context 'When user is login.gov authenticated' do
        let(:user) { create(:user, :accountable_with_logingov_uuid, authn_context: IAL::LOGIN_GOV_IAL2) }
        let(:user_verification) { create(:logingov_user_verification, logingov_uuid: user.logingov_uuid) }
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :with_avc, user_account:)
        end

        it 'does not send an email' do
          expect(VANotify::EmailJob).not_to receive(:perform_async)

          service.perform
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

        it 'does not send an email' do
          expect(VANotify::EmailJob).not_to receive(:perform_async)

          service.perform
        end

        it 'does not log attempt' do
          service.perform
          expect(StatsD).to have_received(:increment).exactly(0).times
        end
      end

      context 'User is mhv authenticated', pending: 'Temporary test to only dsl/avc users' do
        context 'When user has avc' do
          let(:user) { create(:user, :mhv, authn_context: SAML::User::MHV_ORIGINAL_CSID) }
          let(:user_verification) { create(:mhv_user_verification, mhv_uuid: user.mhv_correlation_id) }
          let!(:user_acceptable_verified_credential) do
            create(:user_acceptable_verified_credential, :with_avc, user_account:)
          end

          it 'sends reactivation email' do
            expect(VANotify::EmailJob).to receive(:perform_async).with(
              user.email,
              reactivation_template,
              {
                'name' => user.first_name,
                'legacy_credential' => 'My HealtheVet',
                'modern_credential' => 'Login.gov'
              }
            )

            service.perform
          end

          it 'logs attempt' do
            service.perform
            expect(StatsD).to have_received(:increment).with(va_notify_log).exactly(1).times
            expect(StatsD).to have_received(:increment).with("#{statsd_key}.reactivation_email.mhv").exactly(1).time
          end
        end
      end

      context 'When user has ivc', pending: 'Temporary test to only dsl/avc users' do
        let(:user) { create(:user, :mhv, authn_context: SAML::User::MHV_ORIGINAL_CSID) }
        let(:user_verification) { create(:mhv_user_verification, mhv_uuid: user.mhv_correlation_id) }
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :with_ivc, acceptable_verified_credential_at: nil, user_account:)
        end

        it 'sends reactivation email' do
          expect(VANotify::EmailJob).to receive(:perform_async).with(
            user.email,
            reactivation_template,
            {
              'name' => user.first_name,
              'legacy_credential' => 'My HealtheVet',
              'modern_credential' => 'ID.me'
            }
          )

          service.perform
        end

        it 'logs attempt' do
          service.perform
          expect(StatsD).to have_received(:increment).with(va_notify_log).exactly(1).times
          expect(StatsD).to have_received(:increment).with("#{statsd_key}.reactivation_email.mhv").exactly(1).time
        end
      end

      context 'When user has no avc/ivc' do
        let(:user) { create(:user, :mhv, authn_context: SAML::User::MHV_ORIGINAL_CSID) }
        let(:user_verification) { create(:mhv_user_verification, mhv_uuid: user.mhv_correlation_id) }
        let!(:user_acceptable_verified_credential) do
          create(:user_acceptable_verified_credential, :without_avc_ivc, user_account:)
        end

        it 'does not send an email' do
          expect(VANotify::EmailJob).not_to receive(:perform_async)

          service.perform
        end

        it 'does not log attempt' do
          service.perform
          expect(StatsD).to have_received(:increment).exactly(0).times
        end
      end
    end

    context 'When Flipper organic_conversion_experiment is disabled' do
      before do
        Flipper.disable(:organic_conversion_experiment)
      end

      it 'does not send an email' do
        expect(VANotify::EmailJob).not_to receive(:perform_async)

        service.perform
      end

      it 'does not log attempt' do
        service.perform
        expect(StatsD).to have_received(:increment).exactly(0).times
      end
    end
  end
end
