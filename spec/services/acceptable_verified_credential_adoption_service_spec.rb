# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AcceptableVerifiedCredentialAdoptionService do
  let(:service) { AcceptableVerifiedCredentialAdoptionService.new(user) }
  let(:user) { create(:user) }
  let(:statsd_key) { 'api.user_transition_availability' }

  before { allow(StatsD).to receive(:increment) }

  describe '.perform' do
    context 'when Flipper organic_conversion_experiment is enabled' do
      context 'User is dslogon authenticated' do
        context 'When user has avc' do
          let(:user) { create(:user, :dslogon, :accountable_with_logingov_uuid) }

          it 'hash returns false' do
            expect(service.perform).to include(organic_modal: false)
          end

          it 'does not log attempt' do
            service.perform
            expect(StatsD).to have_received(:increment).exactly(0).times
          end
        end

        context 'When user has ivc' do
          let(:user) { create(:user, :dslogon, :accountable) }

          it 'hash returns false' do
            expect(service.perform).to include(organic_modal: false)
          end

          it 'does not log attempt' do
            service.perform
            expect(StatsD).to have_received(:increment).exactly(0).times
          end
        end

        context 'When user has no avc/ivc' do
          let(:user) { create(:user, :dslogon) }

          it 'hash returns true' do
            result = service.perform
            expect(result).to include(organic_modal: true)
            expect(result).to include(credential_type: SAML::User::DSLOGON_CSID)
          end

          it 'logs attempt' do
            service.perform
            expect(StatsD).to have_received(:increment).exactly(1).times
            expect(StatsD).to have_received(:increment).with("#{statsd_key}.organic_modal.dslogon").exactly(1).time
          end
        end
      end

      context 'When user is not dslogon authenticated' do
        let(:user) { create(:user, :accountable_with_logingov_uuid) }

        it 'hash returns false' do
          expect(service.perform).to include(organic_modal: false)
        end

        it 'does not log attempt' do
          service.perform
          expect(StatsD).to have_received(:increment).exactly(0).times
        end
      end

      context 'User is mhv authenticated' do
        context 'When user has avc' do
          let(:user) { create(:user, :mhv, :accountable_with_logingov_uuid) }

          it 'hash returns false' do
            expect(service.perform).to include(organic_modal: false)
          end

          it 'does not log attempt' do
            service.perform
            expect(StatsD).to have_received(:increment).exactly(0).times
          end
        end
      end

      context 'When user has ivc' do
        let(:user) { create(:user, :mhv, :accountable) }

        it 'hash returns false' do
          expect(service.perform).to include(organic_modal: false)
        end

        it 'does not log attempt' do
          service.perform
          expect(StatsD).to have_received(:increment).exactly(0).times
        end
      end

      context 'When user has no avc/ivc' do
        let(:user) { create(:user, :mhv) }

        it 'hash returns true' do
          result = service.perform
          expect(result).to include(organic_modal: true)
          expect(result).to include(credential_type: SAML::User::MHV_ORIGINAL_CSID)
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
