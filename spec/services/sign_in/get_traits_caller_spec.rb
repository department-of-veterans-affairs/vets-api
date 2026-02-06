# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/attr_package'

RSpec.describe SignIn::GetTraitsCaller do
  subject(:get_traits_caller) { described_class.new(user_attributes) }

  let(:idme_uuid) { 'idme-uuid' }
  let(:logingov_uuid) { nil }
  let(:csp_email) { 'test@example.com' }

  let(:user_attributes) do
    {
      idme_uuid:,
      logingov_uuid:,
      csp_email:,
      first_name: 'Jane',
      last_name: 'Doe',
      birth_date: '1990-01-01',
      ssn: '123456789',
      address: {
        street1: '123 Main',
        city: 'Springfield',
        state: 'VA',
        zipcode: '12345'
      }
    }
  end

  let(:cache_key) { 'cache-key' }

  before do
    allow(Sidekiq::AttrPackage).to receive(:create).and_return(cache_key)
    allow(Identity::GetSSOeTraitsByCspidJob).to receive(:perform_async)
    allow(Rails.logger).to receive(:info)
  end

  describe '#perform_async' do
    context 'when get traits call is successful' do
      shared_examples 'get traits caller' do |credential_type:, csp_uuid:|
        it 'creates a cache key and enqueues the SSOe traits job' do
          get_traits_caller.perform_async

          expect(Sidekiq::AttrPackage).to have_received(:create)
          expect(Identity::GetSSOeTraitsByCspidJob)
            .to have_received(:perform_async)
            .with(cache_key, credential_type, send(csp_uuid))
        end
      end

      context 'with idme' do
        it_behaves_like 'get traits caller',
                        credential_type: 'idme',
                        csp_uuid: :idme_uuid
      end

      context 'with logingov' do
        let(:idme_uuid) { nil }
        let(:logingov_uuid) { 'logingov-uuid' }

        it_behaves_like 'get traits caller',
                        credential_type: 'logingov',
                        csp_uuid: :logingov_uuid
      end
    end

    context 'get traits call is unseccessful' do
      context 'when credential attribute is missing' do
        context 'when csp_email is missing' do
          let(:csp_email) { nil }

          it 'logs and does not enqueue the job' do
            get_traits_caller.perform_async

            expect(Rails.logger).to have_received(:info)
              .with(
                '[SignInService] SSOe get traits skipped due to missing credential data',
                hash_including(missing_credential_type: 'credential_email')
              )

            expect(Identity::GetSSOeTraitsByCspidJob).not_to have_received(:perform_async)
          end
        end

        context 'when credential_method is missing' do
          before do
            allow_any_instance_of(SignIn::GetTraitsCaller)
              .to receive(:credential_method)
              .and_return(nil)
          end

          it 'logs and does not enqueue the job' do
            get_traits_caller.perform_async

            expect(Rails.logger).to have_received(:info)
              .with(
                '[SignInService] SSOe get traits skipped due to missing credential data',
                hash_including(missing_credential_type: 'credential_method')
              )

            expect(Identity::GetSSOeTraitsByCspidJob).not_to have_received(:perform_async)
          end
        end

        context 'when credential_uuid is missing' do
          let(:idme_uuid) { nil }

          it 'logs and does not enqueue the job' do
            get_traits_caller.perform_async

            expect(Rails.logger).to have_received(:info)
              .with(
                '[SignInService] SSOe get traits skipped due to missing credential data',
                hash_including(missing_credential_type: 'credential_uuid')
              )

            expect(Identity::GetSSOeTraitsByCspidJob).not_to have_received(:perform_async)
          end
        end
      end

      context 'and cache_key is nil' do
        let(:cache_key) { nil }

        it 'does not enqueue the job' do
          get_traits_caller.perform_async

          expect(Sidekiq::AttrPackage).to have_received(:create)
          expect(Identity::GetSSOeTraitsByCspidJob).not_to have_received(:perform_async)
        end
      end

      context 'and creating the cache key raises an exception' do
        before do
          allow(Sidekiq::AttrPackage).to receive(:create)
            .and_raise(StandardError, 'cache failure')
        end

        it 'rescues, logs, and does not enqueue the job' do
          expect { get_traits_caller.perform_async }.not_to raise_error

          expect(Rails.logger).to have_received(:info)
            .with(
              '[SignIn][GetTraitsCaller] get_traits error',
              hash_including(:error)
            )

          expect(Identity::GetSSOeTraitsByCspidJob).not_to have_received(:perform_async)
        end
      end

      context 'and enqueuing the job raises an exception' do
        before do
          allow(Identity::GetSSOeTraitsByCspidJob).to receive(:perform_async)
            .and_raise(StandardError, 'boom')
        end

        it 'rescues and logs without raising' do
          expect { get_traits_caller.perform_async }.not_to raise_error

          expect(Rails.logger).to have_received(:info)
            .with(
              '[SignIn][GetTraitsCaller] get_traits error',
              hash_including(:error)
            )
        end
      end
    end
  end
end
