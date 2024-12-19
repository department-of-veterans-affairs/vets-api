# frozen_string_literal: true

require 'rails_helper'

describe Eps::DriveTimeService do
  subject(:service) { described_class.new(user) }

  let(:icn) { '123ICN' }
  let(:user) { double('User', account_uuid: '1234', icn:) }
  let(:successful_drive_time_response) do
    double('Response', status: 200, body: {
        'destinations' => {
          '00eff3f3-ecfb-41ff-9ebc-78ed811e17f9' => {
            'distanceInMiles' => '4',
            'driveTimeInSecondsWithTraffic' => '566',
            'driveTimeInSecondsWithoutTraffic' => '493',
            'latitude' => '-74.12870564772521',
            'longitude' => '-151.6240405624497'
          },
          '69cd9203-5e92-47a3-aa03-94b03752872a' => {
            'distanceInMiles' => '9',
            'driveTimeInSecondsWithTraffic' => '1314',
            'driveTimeInSecondsWithoutTraffic' => '1039',
            'latitude' => '-1.7437745123171688',
            'longitude' => '-54.19187859370315'
          }
        },
        'origin' => {
          'latitude' => '4.627174468915552',
          'longitude' => '-88.72187894562788'
        }
      })
  end
  let(:referral_id) { 'test-referral-id' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  # TODO: make successful_referrals_response test object,
  # once we know what that should look like.

  before do
    allow(Rails.cache).to receive(:fetch).and_return(memory_store)
    Rails.cache.clear
  end

  describe 'get_drive_times' do
    context 'when requesting drive times for a logged in user' do
      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(successful_drive_time_response)
      end

      it 'returns the calculated drive times' do
        exp_response = OpenStruct.new(successful_drive_time_response.body)

        expect(service.get_drive_times).to eq(exp_response)
      end
    end

    context 'when the endpoint fails to return appointments' do
      let(:failed_drive_time_response) do
        double('Response', status: 500, body: 'Unknown service exception')
      end
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, failed_drive_time_response.status,
        failed_drive_time_response.body)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(exception)
      end

      it 'throws exception' do
        expect { service.get_drive_times }.to raise_error(Common::Exceptions::BackendServiceException,
                                                           /VA900/)
      end
    end
  end
end