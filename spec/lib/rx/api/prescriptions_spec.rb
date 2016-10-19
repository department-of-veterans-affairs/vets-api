# frozen_string_literal: true
require 'rails_helper'
require 'rx/client'
require 'support/rx_client_helpers'

describe Rx::Client do
  include Rx::ClientHelpers

  subject(:client) { authenticated_client }
  let(:active_rxs) { File.read('spec/support/fixtures/get_active_rxs.json') }
  let(:history_rxs) { File.read('spec/support/fixtures/get_history_rxs.json') }
  let(:rx) { File.read('spec/support/fixtures/get_rx_1435525.json') }
  let(:post_refill_error) { File.read('spec/support/fixtures/post_refill_error.json') }
  let(:tracking_rx) { File.read('spec/support/fixtures/rx_tracking_1435525.json') }

  it 'should have #get_active_rxs that returns a Collection' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/getactiverx', active_rxs)
    expect(client.get_active_rxs).to be_a(Common::Collection)
  end

  it 'should have #get_history_rxs that returns a Collection' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs)
    expect(client.get_history_rxs).to be_a(Common::Collection)
  end

  it 'should have #get_rx(id) that returns a Prescription' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/gethistoryrx', history_rxs)
    expect(client.get_rx(1_435_525)).to be_a(::Prescription)
  end

  it 'should have #get_tracking_rx(id) that returns a Tracking' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/rxtracking/1435525', tracking_rx)
    response = client.get_tracking_rx(1_435_525)
    expect(response).to be_a(::Tracking)
    expect(response.prescription_id).to eq(1_435_525)
  end

  it 'should have #get_tracking_history_rx(id) that returns a collection of Tracking items' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/rxtracking/1435525', tracking_rx)
    response = client.get_tracking_history_rx(1_435_525)
    expect(response).to be_a(Common::Collection)
    expect(response.members.first.prescription_id).to eq(1_435_525)
  end

  it 'should post a refill successfully' do
    stub_varx_request(:post, 'mhv-api/patient/v1/prescription/rxrefill/1435525', nil)
    response = client.post_refill_rx(1_435_525)
    expect(response.status).to equal 200
    expect(response.body).to eq('')
  end

  context 'when there is an outage' do
    before do
      Rx::Configuration.instance.breakers_service.begin_forced_outage!
    end

    it 'does not post to the service and gets an error' do
      # stub_varx_request(:post, 'mhv-api/patient/v1/prescription/rxrefill/1435525', nil)
      expect { client.post_refill_rx(1_435_525) }.to raise_error(Breakers::OutageException)
    end
  end

  context 'errors' do
    subject(:not_authenticated_client) { setup_client }
    let(:base_path) { "#{Rx::ClientHelpers::HOST}/mhv-api/patient/v1" }

    it 'should raise NotAuthenticated' do
      expect { not_authenticated_client.get_rx(1_435_525) }
        .to raise_error(Common::Client::Errors::NotAuthenticated, 'Not Authenticated')
    end

    it 'should raise RequestTimeout when Faraday::Error::TimeoutError' do
      stub_request(:any, "#{base_path}/prescription/gethistoryrx").to_timeout

      expect { client.get_rx(1_435_525) }
        .to raise_error(Common::Client::Errors::RequestTimeout)
    end

    it 'should raise Client when Faraday::Error::ClientError' do
      stub_request(:any, "#{base_path}/prescription/gethistoryrx")
        .to_raise(Faraday::Error::ClientError)

      expect { client.get_rx(1_435_525) }
        .to raise_error(Common::Client::Errors::Client)
    end

    it 'should raise serialization error if json cannot be parsed' do
      stub_varx_request(:get,
                        'mhv-api/patient/v1/prescription/gethistoryrx',
                        '{ "a\': "sdff" }',
                        status_code: 200)
      expect { client.get_rx(1_435_525) }
        .to raise_error(Common::Client::Errors::Serialization)
    end

    it 'should raise error #post_refill_rx' do
      stub_varx_request(:post,
                        'mhv-api/patient/v1/prescription/rxrefill/1435525',
                        post_refill_error,
                        status_code: 400)
      expect { client.post_refill_rx(1_435_525) }
        .to raise_error(Common::Client::Errors::ClientResponse, 'Prescription is not Refillable')
    end
  end

  context 'integration test for breakers' do
    it 'is raises a breakers exception after 50% failure rate' do
      now = Time.current
      start_time = now - 120
      Timecop.freeze(start_time)

      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/getactiverx', active_rxs, status_code: 200)
      20.times do
        client.get_active_rxs
      end

      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/getactiverx', active_rxs, status_code: 500)
      20.times do
        begin
          client.get_active_rxs
        rescue Common::Client::Errors::ClientResponse
          nil
        end
      end

      expect { client.get_active_rxs }.to raise_exception(Breakers::OutageException)

      Timecop.freeze(now)
      stub_varx_request(:get, 'mhv-api/patient/v1/prescription/getactiverx', active_rxs, status_code: 200)
      expect(client.get_active_rxs).to be_a(Common::Collection)
    end
  end
end
