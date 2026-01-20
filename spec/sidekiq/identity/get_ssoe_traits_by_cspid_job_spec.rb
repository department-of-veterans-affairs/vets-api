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
  let(:icn) { '1234567890V123456' }

  before do
    allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return(valid_attrs)
    allow(Sidekiq::AttrPackage).to receive(:delete).with(cache_key)
    allow(StatsD).to receive(:increment)
  end

  shared_examples 'service call failure' do |should_raise: true|
    it 'logs failure and increments failure metric' do
      expect(StatsD).to receive(:increment).with(
        'worker.get_ssoe_traits_by_cspid.failure',
        tags: ["credential_method:#{credential_method}"]
      )

      expect(Rails.logger).to receive(:error).with(
        /\[GetSSOeTraitsByCspidJob\] .*/,
        hash_including(credential_method:, credential_id:)
      )

      if should_raise
        expect do
          job.perform(cache_key, credential_method, credential_id)
        end.to raise_error(StandardError)
      else
        expect do
          job.perform(cache_key, credential_method, credential_id)
        end.not_to raise_error
      end
    end
  end

  context 'when service call is successful' do
    let(:icn) { '1234567890V123456' }

    before do
      allow_any_instance_of(SSOe::Service).to receive(:get_traits).and_return({ success: true, icn: })
    end

    it 'logs success and increments success metric' do
      expect(Rails.logger).to receive(:info).with(
        '[GetSSOeTraitsByCspidJob] SSOe::Service.get_traits success',
        hash_including(icn:, credential_method:, credential_id:)
      )

      expect(StatsD).to receive(:increment).with('worker.get_ssoe_traits_by_cspid.success',
                                                 tags: ["credential_method:#{credential_method}"])
      expect(Sidekiq::AttrPackage).to receive(:delete).with(cache_key)

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

      it 'logs failure and returns early without raising' do
        expect(Rails.logger).to receive(:error).with(
          '[GetSSOeTraitsByCspidJob] Missing attributes in Redis for key',
          hash_including(credential_method:, credential_id:)
        )

        expect(StatsD).to receive(:increment).with('worker.get_ssoe_traits_by_cspid.failure',
                                                   tags: ["credential_method:#{credential_method}"])
        expect(Sidekiq::AttrPackage).not_to receive(:delete)

        job.perform(cache_key, credential_method, credential_id)
      end
    end

    context 'when user is invalid' do
      before do
        invalid_attrs = valid_attrs.merge(first_name: nil)
        allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return(invalid_attrs)
      end

      it 'logs validation failure and returns early' do
        expect(Rails.logger).to receive(:error).with(
          /Invalid user attributes/,
          hash_including(credential_method:, credential_id:)
        )

        expect(StatsD).to receive(:increment).with('worker.get_ssoe_traits_by_cspid.failure',
                                                   tags: ["credential_method:#{credential_method}"])
        expect(Sidekiq::AttrPackage).not_to receive(:delete)

        job.perform(cache_key, credential_method, credential_id)
      end

      it_behaves_like 'service call failure', should_raise: false
    end

    context 'when an SSOe service error occurs' do
      before do
        allow_any_instance_of(SSOe::Service).to receive(:get_traits)
          .and_raise(SSOe::Errors::ServerError, 'Connection timeout')
      end

      it 'logs and re-raises the SSOe error' do
        expect(Rails.logger).to receive(:error).with(
          '[GetSSOeTraitsByCspidJob] SSOe service error: SSOe::Errors::ServerError - Connection timeout',
          hash_including(credential_method:, credential_id:)
        )

        expect(StatsD).to receive(:increment).with(
          'worker.get_ssoe_traits_by_cspid.failure',
          tags: ["credential_method:#{credential_method}"]
        )

        expect do
          job.perform(cache_key, credential_method, credential_id)
        end.to raise_error(SSOe::Errors::ServerError, /Connection timeout/)
      end
    end

    context 'when an AttrPackage error occurs' do
      before do
        allow(Sidekiq::AttrPackage).to receive(:find)
          .and_raise(Sidekiq::AttrPackageError.new('find', 'Redis connection failed'))
      end

      it 'logs and re-raises the AttrPackage error' do
        expect(Rails.logger).to receive(:error).with(
          '[GetSSOeTraitsByCspidJob] AttrPackage error: Sidekiq::AttrPackageError - ' \
          '[Sidekiq] [AttrPackage] find error: Redis connection failed',
          hash_including(credential_method:, credential_id:)
        )

        expect(StatsD).to receive(:increment).with(
          'worker.get_ssoe_traits_by_cspid.failure',
          tags: ["credential_method:#{credential_method}"]
        )

        expect do
          job.perform(cache_key, credential_method, credential_id)
        end.to raise_error(Sidekiq::AttrPackageError, /Redis connection failed/)
      end
    end

    it 'logs failure, increments metric, does not delete cache, and raises' do
      expect(Rails.logger).to receive(:error).with(
        '[GetSSOeTraitsByCspidJob] SSOe::Service.get_traits failed',
        hash_including(credential_method:, credential_id:, error: error_response[:error])
      )

      expect(StatsD).to receive(:increment).with('worker.get_ssoe_traits_by_cspid.failure',
                                                 tags: ["credential_method:#{credential_method}"])

      expect(Sidekiq::AttrPackage).not_to receive(:delete)

      expect do
        job.perform(cache_key, credential_method, credential_id)
      end.to raise_error(/SSOe::Service.get_traits failed/)
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
