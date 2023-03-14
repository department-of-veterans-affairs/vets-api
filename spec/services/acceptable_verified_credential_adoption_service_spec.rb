# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AcceptableVerifiedCredentialAdoptionService do
  let(:service) { AcceptableVerifiedCredentialAdoptionService.new(user) }
  let(:user) { create(:user) }

  describe '.perform' do
    context 'when Flipper organic_dsl_conversion_experiment is enabled' do
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
            expect(service.perform).to include(organic_modal: true)
          end
        end
      end

      context 'When user is not dslogon authenticated' do
        let(:user) { create(:user, :accountable_with_logingov_uuid) }

        it 'hash returns false' do
          expect(service.perform).to include(organic_modal: false)
        end
      end
    end

    context 'When Flipper organic_dsl_conversion_experiment is disabled' do
      before do
        Flipper.disable(:organic_dsl_conversion_experiment)
      end

      it 'hash returns false' do
        expect(service.perform).to include(organic_modal: false)
      end
    end
  end
end
