# frozen_string_literal: true

require 'rails_helper'

describe V2::Chip::Client do
  subject { described_class }

  describe '.build' do
    it 'returns an instance of described_class' do
      expect(subject.build).to be_an_instance_of(described_class)
    end
  end

  describe 'extends' do
    it 'extends forwardable' do
      expect(subject.ancestors).to include(Forwardable)
    end
  end

  describe '#initialize' do
    it 'has settings attribute' do
      expect(subject.build.settings).to be_a(Config::Options)
    end

    it 'has a claims_token attribute' do
      expect(subject.build.claims_token).to be_a(V2::Chip::ClaimsToken)
    end

    it 'has a session' do
      expect(subject.build(check_in_session: CheckIn::V2::Session.build).check_in_session)
        .to be_a(CheckIn::V2::Session)
    end
  end

  describe '#token' do
    let(:chip_token_response) { Faraday::Response.new(body: { 'token' => 'abc123' }, status: 200) }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(chip_token_response)
    end

    it 'post is called once' do
      expect_any_instance_of(Faraday::Connection).to receive(:post).with('/dev/token').once

      subject.build.token
    end

    it 'yields to block' do
      expect_any_instance_of(Faraday::Connection).to receive(:post)
        .with('/dev/token').and_yield(Faraday::Request.new)

      subject.build.token
    end
  end

  describe '#check_in_appointment' do
    let(:check_in_response) { Faraday::Response.new(body: 'success', status: 200) }
    let(:check_in_session) { CheckIn::V2::Session.build }
    let(:uuid) { Faker::Internet.uuid }
    let(:token) { 'abc123' }
    let(:appointment_ien) { '4567' }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(check_in_response)
      allow(check_in_session).to receive(:uuid).and_return(uuid)
      allow_any_instance_of(subject).to receive(:check_in_session).and_return(check_in_session)
    end

    it 'post is called once' do
      expect_any_instance_of(Faraday::Connection).to receive(:post).with("/dev/actions/check-in/#{uuid}").once

      subject.build(check_in_session: check_in_session)
             .check_in_appointment(token: token, appointment_ien: appointment_ien)
    end

    it 'yields to block' do
      expect_any_instance_of(Faraday::Connection).to receive(:post)
        .with("/dev/actions/check-in/#{uuid}").and_yield(Faraday::Request.new)

      subject.build(check_in_session: check_in_session)
             .check_in_appointment(token: token, appointment_ien: appointment_ien)
    end
  end

  describe '#refresh_appointments' do
    let(:check_in_response) { Faraday::Response.new(body: 'success', status: 200) }
    let(:check_in_session) { CheckIn::V2::Session.build }
    let(:uuid) { Faker::Internet.uuid }
    let(:token) { 'abc123' }
    let(:identifier_params) { {} }

    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(check_in_response)
      allow(check_in_session).to receive(:uuid).and_return(uuid)
      allow_any_instance_of(subject).to receive(:check_in_session).and_return(check_in_session)
    end

    it 'post is called once' do
      expect_any_instance_of(Faraday::Connection).to receive(:post)
        .with("/dev/actions/refresh-appointments/#{uuid}").once

      subject.build(check_in_session: check_in_session)
             .refresh_appointments(token: token, identifier_params: identifier_params)
    end

    it 'yields to block' do
      expect_any_instance_of(Faraday::Connection).to receive(:post)
        .with("/dev/actions/refresh-appointments/#{uuid}").and_yield(Faraday::Request.new)

      subject.build(check_in_session: check_in_session)
             .refresh_appointments(token: token, identifier_params: identifier_params)
    end
  end
end
