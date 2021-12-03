# frozen_string_literal: true

require 'rails_helper'

describe V2::Chip::Client do
  subject { described_class.build(check_in_session: check_in_session) }

  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in_session) { CheckIn::V2::Session.build(data: { uuid: uuid }) }

  describe '.build' do
    it 'returns an instance of described_class' do
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe 'extends' do
    it 'extends forwardable' do
      expect(described_class.ancestors).to include(Forwardable)
    end
  end

  describe '#initialize' do
    it 'has settings attribute' do
      expect(subject.settings).to be_a(Config::Options)
    end

    it 'has a claims_token attribute' do
      expect(subject.claims_token).to be_a(V2::Chip::ClaimsToken)
    end

    it 'has a session' do
      expect(subject.check_in_session).to be_a(CheckIn::V2::Session)
    end
  end

  describe '#token' do
    let(:chip_token_response) { Faraday::Response.new(body: { 'token' => 'abc123' }, status: 200) }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(chip_token_response)
    end

    it 'yields to block' do
      expect_any_instance_of(Faraday::Connection).to receive(:post).with('/dev/token').and_yield(Faraday::Request.new)

      subject.token
    end

    it 'returns token' do
      expect(subject.token).to eq(chip_token_response)
    end
  end

  describe '#check_in_appointment' do
    let(:response) { Faraday::Response.new(body: 'success', status: 200) }
    let(:token) { 'abc123' }
    let(:appointment_ien) { '4567' }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(response)
    end

    it 'yields to block' do
      expect_any_instance_of(Faraday::Connection).to receive(:post)
        .with("/dev/actions/check-in/#{uuid}").and_yield(Faraday::Request.new)

      subject.check_in_appointment(token: token, appointment_ien: appointment_ien)
    end

    it 'returns success response' do
      expect(subject.check_in_appointment(token: token, appointment_ien: appointment_ien)).to eq(response)
    end
  end

  describe '#refresh_appointments' do
    let(:response) { Faraday::Response.new(body: 'success', status: 200) }
    let(:token) { 'abc123' }
    let(:identifier_params) { {} }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(response)
    end

    it 'yields to block' do
      expect_any_instance_of(Faraday::Connection).to receive(:post)
        .with("/dev/actions/refresh-appointments/#{uuid}").and_yield(Faraday::Request.new)

      subject.refresh_appointments(token: token, identifier_params: identifier_params)
    end

    it 'returns success response' do
      expect(subject.refresh_appointments(token: token, identifier_params: identifier_params)).to eq(response)
    end
  end

  describe '#pre_check_in' do
    let(:response) { Faraday::Response.new(body: 'Pre-checkin successful', status: 200) }
    let(:token) { 'abc123' }
    let(:demographic_confirmations) do
      {
        demographicConfirmations: {
          demographicsNeedsUpdate: true,
          demographicsConfirmedAt: '2021-11-30T20:45:03.779Z',
          nextOfKinNeedsUpdate: true,
          nextOfConfirmedAt: '2021-11-30T20:45:03.779Z',
          emergencyContactNeedsUpdate: true,
          emergencyContactConfirmedAt: '2021-11-30T20:45:03.779Z'
        }
      }
    end

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(response)
    end

    it 'yields to block' do
      expect_any_instance_of(Faraday::Connection).to receive(:post)
        .with("/dev/actions/pre-checkin/#{uuid}").and_yield(Faraday::Request.new)

      subject.pre_check_in(token: token, demographic_confirmations: demographic_confirmations)
    end

    it 'returns success response' do
      expect(subject.pre_check_in(token: token, demographic_confirmations: demographic_confirmations)).to eq(response)
    end
  end
end
