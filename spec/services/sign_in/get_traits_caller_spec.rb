# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/attr_package'

RSpec.describe SignIn::GetTraitsCaller do
  subject(:perform_async) { described_class.new(user_attributes).perform_async }

  let(:user_attributes) do
    {
      idme_uuid: 'idme-uuid',
      logingov_uuid: nil,
      csp_email: 'test@example.com',
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
    allow(StatsD).to receive(:increment)
  end

  describe '#perform_async' do
    context 'when user_attributes are valid and cache_key exists' do
      it 'creates a cache key and enqueues the SSOe traits job' do
        perform_async

        expect(Sidekiq::AttrPackage).to have_received(:create)
        expect(Identity::GetSSOeTraitsByCspidJob)
          .to have_received(:perform_async)
          .with(cache_key, 'idme', 'idme-uuid')
      end
    end

    context 'when there are missing or invalid params' do
      context 'and user attributes are missing' do
        let(:user_attributes) do
          super().merge(csp_email: nil)
        end

        it 'does not create a cache key or enqueue the job' do
          perform_async

          expect(Sidekiq::AttrPackage).not_to have_received(:create)
          expect(Identity::GetSSOeTraitsByCspidJob).not_to have_received(:perform_async)
        end
      end

      context 'and cache_key is nil' do
        let(:cache_key) { nil }

        it 'still enqueues the job with a nil cache_key' do
          perform_async

          expect(Sidekiq::AttrPackage).to have_received(:create)
          expect(Identity::GetSSOeTraitsByCspidJob)
            .to have_received(:perform_async)
            .with(nil, 'idme', 'idme-uuid')
        end
      end

      context 'and creating the cache key raises an exception' do
        before do
          allow(Sidekiq::AttrPackage).to receive(:create)
            .and_raise(StandardError, 'cache failure')
        end

        it 'rescues, logs, increments stats, and does not enqueue the job' do
          expect { perform_async }.not_to raise_error

          expect(StatsD).to have_received(:increment)
            .with('api.ssoe.traits.failure')
          expect(Identity::GetSSOeTraitsByCspidJob).not_to have_received(:perform_async)
        end
      end

      context 'and enqueuing the job raises an exception' do
        before do
          allow(Identity::GetSSOeTraitsByCspidJob).to receive(:perform_async)
            .and_raise(StandardError, 'boom')
        end

        it 'rescues and increments stats without raising' do
          expect { perform_async }.not_to raise_error

          expect(StatsD).to have_received(:increment)
            .with('api.ssoe.traits.failure')
        end
      end
    end
  end
end
