# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/attr_package'
require 'ssoe/service'
require 'ssoe/models/user'
require 'ssoe/models/address'

# rubocop:disable RSpec/SpecFilePathFormat

RSpec.describe Identity::GetSSOeTraitsByCspidJob, type: :job do
  let(:job) { described_class.new }
  let(:cache_key) { SecureRandom.hex(32) }

  let(:valid_attrs) do
    {
      first_name: 'Jane',
      last_name: 'Doe',
      birth_date: '1980-01-01',
      ssn: '123456789',
      email: 'jane.doe@example.com',
      phone: '5551234567',
      street1: '123 Main St',
      city: 'Anytown',
      state: 'CA',
      zipcode: '90210'
    }
  end

  let(:credential_method) { 'idme' }
  let(:credential_id) { 'abc-123' }

  before do
    allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return(valid_attrs)
    allow(Sidekiq::AttrPackage).to receive(:delete).with(cache_key)
    allow(StatsD).to receive(:increment)
  end

  shared_examples 'service call failure' do
    it 'logs failure and increments failure metric' do
      expect(StatsD).to receive(:increment).with('worker.get_ssoe_traits_by_cspid.failure', anything)
      expect(Rails.logger).to receive(:error).with(/\[GetSSOeTraitsByCspidJob\].*/)
      job.perform(cache_key, credential_method, credential_id)
    end
  end

  context 'when service call is successful' do
    before do
      allow_any_instance_of(SSOe::Service).to receive(:get_traits).and_return({ success: true, icn: 'icn-12345' })
    end

    it 'logs success and increments success metric' do
      expect(Rails.logger).to receive(:info).with(/\[GetSSOeTraitsByCspidJob\] SSOe::Service.get_traits success/)
      expect(StatsD).to receive(:increment).with('worker.get_ssoe_traits_by_cspid.success', anything)

      job.perform(cache_key, credential_method, credential_id)
    end
  end

  context 'when service call fails' do
    let(:error_response) do
      {
        success: false,
        error: {
          code: 'SOAPFault',
          message: 'Something went wrong'
        }
      }
    end

    before do
      allow_any_instance_of(SSOe::Service).to receive(:get_traits).and_return(error_response)
    end

    context 'when attributes are missing from Redis' do
      before do
        allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return(nil)
      end

      it 'logs failure and returns early' do
        expect(Rails.logger).to receive(:error).with(/\[GetSSOeTraitsByCspidJob\] Missing attributes in Redis/)
        expect(StatsD).to receive(:increment).with('worker.get_ssoe_traits_by_cspid.failure', anything)

        job.perform(cache_key, credential_method, credential_id)
      end

      it_behaves_like 'service call failure'
    end

    context 'when user is invalid' do
      before do
        invalid_attrs = valid_attrs.merge(first_name: nil)
        allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return(invalid_attrs)
      end

      it 'logs failure due to validation and returns early' do
        expect(Rails.logger).to receive(:error).with(/Invalid user attributes/)
        expect(StatsD).to receive(:increment).with('worker.get_ssoe_traits_by_cspid.failure', anything)

        job.perform(cache_key, credential_method, credential_id)
      end

      it_behaves_like 'service call failure'
    end

    context 'when an unhandled exception occurs' do
      before do
        allow(Sidekiq::AttrPackage).to receive(:find).and_raise(StandardError, 'Unexpected crash')
      end

      it 'logs and re-raises the exception' do
        expect(Rails.logger).to receive(:error).with(
          /\[GetSSOeTraitsByCspidJob\] Unhandled exception: StandardError - Unexpected crash/
        )
        expect(StatsD).to receive(:increment).with('worker.get_ssoe_traits_by_cspid.failure', anything)

        expect do
          job.perform(cache_key, credential_method, credential_id)
        end.to raise_error(StandardError, /Unexpected crash/)
      end
    end

    it 'logs failure and increments failure metric' do
      expect(Rails.logger).to receive(:error).with(/\[GetSSOeTraitsByCspidJob\] SSOe::Service.get_traits failed/)
      expect(StatsD).to receive(:increment).with('worker.get_ssoe_traits_by_cspid.failure', anything)

      job.perform(cache_key, credential_method, credential_id)
    end
  end

  it 'always deletes the cache key' do
    allow_any_instance_of(SSOe::Service).to receive(:get_traits).and_return({ success: true, icn: 'icn-12345' })

    expect(Sidekiq::AttrPackage).to receive(:delete).with(cache_key)

    job.perform(cache_key, credential_method, credential_id)
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
