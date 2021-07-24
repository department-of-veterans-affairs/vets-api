# frozen_string_literal: true

require 'rails_helper'

describe ChipApi::Service do
  subject { described_class }

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.build).to be_an_instance_of(ChipApi::Service)
    end
  end

  describe '#get_check_in' do
    Timecop.freeze(Time.zone.now)

    let(:id) { '123abc' }
    let(:opts) do
      {
        path: '/dev/appointments/123abc',
        access_token: 'abc123'
      }
    end
    let(:resp) do
      {
        startTime: Time.zone.now.to_s,
        facility: 'Acme VA',
        clinicPhoneNumber: '555-555-5555',
        clinicFriendlyName: 'Clinic1',
        clinicName: 'Green Team Clinic1'
      }
    end
    let(:faraday_response) { Faraday::Response.new(body: resp.to_json, status: 200) }

    it 'returns a Faraday::Response' do
      allow_any_instance_of(ChipApi::Session).to receive(:retrieve).and_return('abc123')
      allow_any_instance_of(ChipApi::Request).to receive(:get).with(opts).and_return(faraday_response)

      hsh = { data: Oj.load(faraday_response.body), status: faraday_response.status }

      expect(subject.build.get_check_in(id)).to eq(hsh)
    end

    Timecop.return
  end

  describe '#create_check_in' do
    let(:opts) do
      {
        path: '/dev/actions/check-in/789',
        access_token: 'abc123'
      }
    end
    let(:resp) { 'Checkin successful' }
    let(:faraday_response) { Faraday::Response.new(body: resp, status: 200) }

    it 'returns a Faraday::Response' do
      allow_any_instance_of(ChipApi::Session).to receive(:retrieve).and_return('abc123')
      allow_any_instance_of(ChipApi::Request).to receive(:post).with(opts).and_return(faraday_response)

      hsh = { data: faraday_response.body, status: faraday_response.status }

      expect(subject.build.create_check_in('789')).to eq(hsh)
    end
  end

  describe '#handle_response' do
    context 'when status 200' do
      context 'when json string' do
        it 'returns a formatted response' do
          resp = Faraday::Response.new(body: { foo: 'bar' }, status: 200)
          hsh = { data: { foo: 'bar' }, status: 200 }

          expect(subject.build.handle_response(resp)).to eq(hsh)
        end
      end

      context 'when non json string' do
        it 'returns a formatted response' do
          resp = Faraday::Response.new(body: 'bar', status: 200)
          hsh = { data: 'bar', status: 200 }

          expect(subject.build.handle_response(resp)).to eq(hsh)
        end
      end
    end

    context 'when status 404' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Not found', status: 404)
        hsh = { data: { error: true, message: 'We could not find that UUID' }, status: resp.status }

        expect(subject.build.handle_response(resp)).to eq(hsh)
      end
    end

    context 'when status 403' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Not authorized', status: 403)
        hsh = { data: { error: true, message: 'Unauthorized access' }, status: resp.status }

        expect(subject.build.handle_response(resp)).to eq(hsh)
      end
    end

    context 'when status 500' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Something went wrong', status: 500)
        hsh = { data: { error: true, message: 'Something went wrong' }, status: resp.status }

        expect(subject.build.handle_response(resp)).to eq(hsh)
      end
    end
  end
end
