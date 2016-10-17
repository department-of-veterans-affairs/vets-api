# frozen_string_literal: true
require 'rails_helper'
require 'rx/client'
require 'support/rx_client_helpers'

describe Rx::Client do
  include Rx::ClientHelpers

  subject(:client) { authenticated_client }
  let(:post_refill_error) { File.read('spec/support/fixtures/post_refill_error.json') }
  let(:tracking_rx) { File.read('spec/support/fixtures/rx_tracking_1435525.json') }

  it 'should have #get_active_rxs that returns a Collection' do
    VCR.use_cassette('prescriptions/responds_to_GET_index_with_refill_status_active') do
      expect(client.get_active_rxs).to be_a(Common::Collection)
    end
  end

  it 'should have #get_history_rxs that returns a Collection' do
    VCR.use_cassette('prescriptions/responds_to_GET_index_with_no_parameters') do
      expect(client.get_history_rxs).to be_a(Common::Collection)
    end
  end

  it 'should have #get_rx(id) that returns a Prescription' do
    VCR.use_cassette('prescriptions/responds_to_GET_show') do
      expect(client.get_rx(13650546)).to be_a(::Prescription)
    end
  end

  xit 'should have #get_tracking_rx(id) that returns a Tracking' do
    VCR.use_cassette('prescriptions/nested_resources/responds_to_GET_show_of_nested_tracking_resource') do
      binding.pry
      response = client.get_tracking_rx(13651310)
      expect(response).to be_a(::Tracking)
      expect(response.prescription_id).to eq(13651310)
    end
  end

  it 'should have #get_tracking_history_rx(id) that returns a collection of Tracking items' do
    stub_varx_request(:get, 'mhv-api/patient/v1/prescription/rxtracking/1435525', tracking_rx)
    response = client.get_tracking_history_rx(1_435_525)
    expect(response).to be_a(Common::Collection)
    expect(response.members.first.prescription_id).to eq(1_435_525)
  end

  it 'should post a refill successfully' do
    VCR.use_cassette('prescriptions/responds_to_POST_refill') do
      response = client.post_refill_rx(13568747)
      expect(response.status).to equal 200
      expect(response.body).to eq(nil)
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
end
