# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AcceptableVerifiedCredentialAdoptionService do
  let(:service) { AcceptableVerifiedCredentialAdoptionService.new(user) }
  let(:user) { create(:user) }

  describe '.perform' do
    context 'when Flipper organic_conversion_experiment is enabled' do
      context 'User is dslogon authenticated' do
        context 'When user has avc' do
          let(:user) { create(:user, :dslogon, :accountable_with_logingov_uuid) }

          it 'hash returns false' do
            expect(service.perform).to include(organic_modal: false)
          end
        end

        context 'When user has ivc' do
          let(:user) { create(:user, :dslogon, :accountable) }

          it 'hash returns false' do
            expect(service.perform).to include(organic_modal: false)
          end
        end

        context 'When user has no avc/ivc' do
          let(:user) { create(:user, :dslogon) }

          it 'hash returns true' do
            result = service.perform
            expect(result).to include(organic_modal: true)
            expect(result).to include(credential_type: SAML::User::DSLOGON_CSID)
          end
        end
      end

      context 'When user is not dslogon authenticated' do
        let(:user) { create(:user, :accountable_with_logingov_uuid) }

        it 'hash returns false' do
          expect(service.perform).to include(organic_modal: false)
        end
      end

      context 'User is mhv authenticated' do
        context 'When user has avc' do
          let(:user) { create(:user, :mhv, :accountable_with_logingov_uuid) }

          it 'hash returns false' do
            expect(service.perform).to include(organic_modal: false)
          end
        end
      end

      context 'When user has ivc' do
        let(:user) { create(:user, :mhv, :accountable) }

        it 'hash returns false' do
          expect(service.perform).to include(organic_modal: false)
        end
      end

      context 'When user has no avc/ivc' do
        let(:user) { create(:user, :mhv) }

        it 'hash returns true' do
          result = service.perform
          expect(result).to include(organic_modal: true)
          expect(result).to include(credential_type: SAML::User::MHV_ORIGINAL_CSID)
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
    end
  end
end
