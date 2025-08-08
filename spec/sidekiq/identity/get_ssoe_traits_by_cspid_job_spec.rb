# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require 'sidekiq/attr_package'
require 'ssoe/service'
require 'ssoe/get_ssoe_traits_by_cspid_message'
require 'ssoe/models/user'
require 'ssoe/models/address'

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe Identity::GetSSOeTraitsByCspidJob, type: :job do
  subject(:job) { described_class.new }

  let(:user_uuid) { 'some-uuid' }
  let(:cache_key) { 'some-cache-key' }
  let(:identity) { create(:user_identity) }

  let(:user_attributes) do
    {
      uuid: user_uuid,
      first_name: 'John',
      last_name: 'Doe',
      birth_date: '1980-01-01',
      ssn: '123456789',
      email: 'john.doe@example.com',
      phone: '555-555-5555',
      identity:,
      address: double(street: '123 Main St', city: 'Anytown', state: 'CA', postal_code: '12345')
    }
  end

  before do
    allow(Settings).to receive(:vsp_environment).and_return('localhost')
    allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return(user_attributes)
  end

  describe '#perform' do
    context 'when in production' do
      it 'does not perform the job' do
        allow(Settings).to receive(:vsp_environment).and_return('production')

        expect(Sidekiq::AttrPackage).not_to receive(:find)

        job.perform(cache_key)
      end
    end

    context 'when in non-production' do
      context 'when response includes an ICN' do
        let(:ssoe_response) { { icn: 'some-icn' } }

        it 'logs success and increments StatsD success metric' do
          allow(SSOe::Service).to receive(:new).and_return(
            instance_double(SSOe::Service, get_traits: ssoe_response)
          )

          expect(Rails.logger).to receive(:info).with(
            /\[GetSSOeTraitsByCspidJob\] Success for user #{user_uuid}, ICN: some-icn/
          )
          expect(StatsD).to receive(:increment).with('ssoe.traits_fetch.success')

          job.perform(cache_key)
        end
      end

      context 'when response does not include an ICN' do
        let(:ssoe_response) { { success: false, error: { code: '500', message: 'Server error' } } }

        it 'logs failure and increments StatsD failure metric' do
          allow(SSOe::Service).to receive(:new).and_return(
            instance_double(SSOe::Service, get_traits: ssoe_response)
          )

          expect(Rails.logger).to receive(:warn).with(
            "[GetSSOeTraitsByCspidJob] Failure for user #{user_uuid}", ssoe_response
          )
          expect(StatsD).to receive(:increment).with('ssoe.traits_fetch.failure')

          job.perform(cache_key)
        end
      end

      context 'when an unexpected error occurs' do
        it 'logs the error and increments StatsD error metric' do
          allow(Sidekiq::AttrPackage).to receive(:find).and_raise(StandardError.new('something went wrong'))

          expect(Rails.logger).to receive(:error).with(
            /\[GetSSOeTraitsByCspidJob\] Unexpected error: something went wrong/
          )
          expect(StatsD).to receive(:increment).with('ssoe.traits_fetch.unexpected_error')

          job.perform(cache_key)
        end
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
