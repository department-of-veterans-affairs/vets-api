# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/bb_internal/client'
require 'stringio'

UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

describe BBInternal::Client do
  let(:client) { @client }

  RSpec.shared_context 'redis setup' do
    let(:redis) { instance_double(Redis::Namespace) }
    let(:study_id) { '453-2487450' }
    let(:uuid) { 'c9396040-23b7-44bc-a505-9127ed968b0d' }
    let(:cached_data) do
      {
        uuid => study_id
      }.to_json
    end
    let(:namespace) { REDIS_CONFIG[:bb_internal_store][:namespace] }
    let(:study_data_key) { 'study_data-11382904' }

    before do
      allow(Redis::Namespace).to receive(:new).with(namespace, redis: $redis).and_return(redis)
      allow(redis).to receive(:get).with(study_data_key).and_return(cached_data)
    end
  end

  context 'using API Gateway endpoints' do
    before do
      VCR.use_cassette 'mr_client/bb_internal/apigw_session_auth' do
        @client ||= begin
          client = BBInternal::Client.new(session: { user_id: '11375034', icn: '1012740022V620959' })
          client.authenticate
          client
        end
      end
    end

    describe '#list_radiology' do
      it 'gets the radiology records' do
        VCR.use_cassette 'mr_client/bb_internal/apigw_get_radiology' do
          radiology_results = client.list_radiology
          expect(radiology_results).to be_an(Array)
          result = radiology_results[0]
          expect(result).to be_a(Hash)
          expect(result).to have_key('procedureName')
        end
      end
    end

    describe '#get_bbmi_notification_setting' do
      it 'retrieves the BBMI notification setting' do
        VCR.use_cassette 'mr_client/bb_internal/apigw_get_bbmi_notification_setting' do
          notification_setting = client.get_bbmi_notification_setting

          expect(notification_setting).to be_a(Hash)
          expect(notification_setting).to have_key('flag')
          expect(notification_setting['flag']).to be(true)
        end
      end
    end
  end
end
