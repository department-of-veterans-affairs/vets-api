# frozen_string_literal: true

require 'rails_helper'
require 'mhv/aal/client'

RSpec.describe AAL::Client do
  let(:client) { @client }
  let(:user_id) { '11375034' }
  let(:session_id) { '2025-05-07T09:00:00Z' }
  let(:attrs) do
    {
      activity_type: 'atype',
      action: 'act',
      completion_time: '2025-05-07T10:00:00Z',
      performer_type: 'ptype',
      detail_value: 'dval',
      status: 'stat'
    }
  end

  # stub out Redis namespace
  let(:redis_ns) { instance_double(Redis::Namespace, exists?: exists, set: true) }
  let(:exists) { false }

  before do
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(true)
    VCR.use_cassette 'mr_client/bb_internal/apigw_session_auth' do
      @client ||= begin
        client = AAL::MRClient.new(session: { user_id: })
        client.authenticate
        client
      end
    end

    # intercept the Redis::Namespace constructor
    allow(Redis::Namespace).to receive(:new).and_return(redis_ns)

    # always flip on the feature
    allow(Flipper).to receive(:enabled?).with(:mhv_enable_aal_integration).and_return(true)

    # stub out form‐building
    stub_form = double('CreateAALForm', params: { some: 'payload' })
    allow(AAL::CreateAALForm).to receive(:new).and_return(stub_form)

    # avoid real HTTP
    allow(client).to receive(:perform)
  end

  describe '#create_aal' do
    context 'when logging once per session with no prior key' do
      it 'writes the Redis key and calls perform' do
        expect(redis_ns).to receive(:exists?)
          .with(kind_of(String)).and_return(false)
        expect(redis_ns).to receive(:set)
          .with(kind_of(String), true, nx: false, ex: REDIS_CONFIG[:mhv_aal_log_store][:each_ttl])
        expect(client).to receive(:perform)
          .with(:post, 'usermgmt/activity', { some: 'payload' }, anything)

        client.create_aal(attrs.dup, true, session_id)
      end
    end

    context 'when logging once per session and key already exists' do
      let(:exists) { true }

      it 'skips the API call' do
        expect(redis_ns).to receive(:exists?).and_return(true)
        expect(client).not_to receive(:perform)

        client.create_aal(attrs, true, session_id)
      end
    end

    context 'when logging multiple times per session' do
      it 'does not touch Redis and always calls perform' do
        expect(redis_ns).not_to receive(:exists?)
        expect(client).to receive(:perform)

        client.create_aal(attrs, false, session_id)
      end
    end
  end

  describe '#aal_redis_key' do
    it 'returns a stable key based on user_id and fingerprint' do
      key1 = client.send(:aal_redis_key, attrs, session_id)
      key2 = client.send(:aal_redis_key, attrs, session_id)

      expect(key1).to eq(key2)
      expect(key1).to start_with("aal:#{user_id}:")
      # fingerprint is a 32‐hex MD5
      expect(key1.split(':').last).to match(/\A[0-9a-f]{32}\z/)
    end
  end
end
