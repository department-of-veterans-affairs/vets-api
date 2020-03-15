# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBMS::Efolder::Service do
  let(:service) { described_class.new }
  let(:vbms_client) { VBMS::Client }

  before do
    service.class.send(:public, *described_class.private_instance_methods)
    allow(VBMS::Client).to receive(:from_env_vars).and_return(vbms_client)
  end

  it 'should configure statsd key prefix' do
    expect(VBMS::Efolder::Service::STATSD_KEY_PREFIX).to eq('api.vbms.efolder')  
  end

  describe '#client' do
    it 'should return a VBMS::Client' do
      expect(service.client).to be(VBMS::Client)
    end
  end

  describe 'statsd helper methods' do
    # set the class name to UploadService to ensure the incrementers convert and use upload_service as keyname
    before { allow(service).to receive(:class).and_return(VBMS::Efolder::UploadService) }
    upload_success_key = 'api.vbms.efolder.upload_service.upload.success'
    upload_fail_key = 'api.vbms.efolder.upload_service.upload.fail'

    # ensure 
    it '#increment_success triggers statsd with correct keyname' do
      expect { service.increment_success(:upload) }.to trigger_statsd_increment(upload_success_key)
      service.increment_success(:upload)
    end

    it '#increment_fail should trigger statsd with correct keyname' do
      expect { service.increment_fail(:upload) }.to trigger_statsd_increment(upload_fail_key)
      service.increment_fail(:upload)
    end
  end
end
