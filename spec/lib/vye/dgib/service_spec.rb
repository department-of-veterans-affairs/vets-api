# frozen_string_literal: true

require 'rails_helper'
require 'vye/dgib/service'

RSpec.describe Vye::DGIB::Service do
  include ActiveSupport::Testing::TimeHelpers
  let(:user) { create(:user, :loa3) }
  let(:service) { described_class.new(user) }

  describe '#claimant_lookup' do
    let(:ssn) { '123-45-6789' }
    let(:json_body) { 'modules/vye/spec/fixtures/claimant_lookup_response.json' }
    let(:response_body) { JSON.parse(File.read(json_body)) }
    let(:successful_mocked_response) { double('faraday_response', status: 200, body: response_body, ok?: true) }

    before do
      allow(service).to receive(:claimant_lookup).with(ssn).and_return(successful_mocked_response)
    end

    context 'when successful' do
      it 'returns a status of 200' do
        travel_to Time.zone.local(2022, 2, 9, 12) do
          response = service.claimant_lookup(ssn)

          expect(response.status).to eq(200)
          expect(response.ok?).to be(true)
        end
      end
    end
  end

  describe '#get_claimant_status' do
    let(:claimant_id) { 600_010_259 }
    let(:json_body) { 'modules/vye/spec/fixtures/claimant_response.json' }
    let(:response_body) { JSON.parse(File.read(json_body)) }
    let(:successful_mocked_response) { double('faraday_response', status: 200, body: response_body, ok?: true) }

    before do
      allow(service).to receive(:get_claimant_status).with(claimant_id).and_return(successful_mocked_response)
    end

    context 'when successful' do
      it 'returns a status of 200' do
        travel_to Time.zone.local(2022, 2, 9, 12) do
          response = service.get_claimant_status(claimant_id)
          expect(response.status).to eq(200)
          expect(response.ok?).to be(true)
        end
      end
    end
  end

  describe '#get_verification_record' do
    let(:claimant_id) { 600_010_259 }
    let(:json_body) { 'modules/vye/spec/fixtures/claimant_response.json' }
    let(:response_body) { JSON.parse(File.read(json_body)) }
    let(:successful_mocked_response) { double('faraday_response', status: 200, body: response_body, ok?: true) }

    before do
      allow(service).to receive(:get_verification_record).with(claimant_id).and_return(successful_mocked_response)
    end

    context 'when successful' do
      it 'returns a status of 200' do
        travel_to Time.zone.local(2022, 2, 9, 12) do
          response = service.get_verification_record(claimant_id)
          expect(response.status).to eq(200)
          expect(response.ok?).to be(true)
        end
      end
    end
  end

  describe '#get_verify_claimant' do
    let(:claimant_id) { 600_010_259 }
    let(:verified_period_begin_date) { '2022-01-01' }
    let(:verified_period_end_date) { '2022-01-31' }
    let(:verified_through_date) { '2022-01-31' }
    let(:verification_method) { 'Initial' }
    let(:response_type) { '200' }
    let(:json_body) { 'modules/vye/spec/fixtures/claimant_lookup_response.json' }
    let(:response_body) { JSON.parse(File.read(json_body)) }
    let(:successful_mocked_response) { double('faraday_response', status: 200, body: response_body, ok?: true) }

    before do
      allow(service).to receive(:verify_claimant)
        .with(
          claimant_id,
          verified_period_begin_date,
          verified_period_end_date,
          verified_through_date,
          verification_method,
          response_type
        )
        .and_return(successful_mocked_response)
    end

    context 'when successful' do
      it 'returns a status of 200' do
        travel_to Time.zone.local(2022, 2, 9, 12) do
          response = service
                     .verify_claimant(claimant_id,
                                      verified_period_begin_date,
                                      verified_period_end_date,
                                      verified_through_date,
                                      verification_method,
                                      response_type)

          expect(response.status).to eq(200)
          expect(response.ok?).to be(true)
        end
      end
    end
  end
end
