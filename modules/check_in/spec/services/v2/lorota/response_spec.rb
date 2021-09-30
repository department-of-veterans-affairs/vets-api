# frozen_string_literal: true

require 'rails_helper'

describe V2::Lorota::Response do
  subject { described_class }

  describe '#handle' do
    context 'when status 200' do
      context 'when json string' do
        it 'returns a formatted response' do
          resp = Faraday::Response.new(body: { foo: 'bar' }, status: 200)
          hsh = { data: { foo: 'bar' }, status: 200 }

          expect(subject.build(response: resp).handle).to eq(hsh)
        end
      end

      context 'when non json string' do
        it 'returns a formatted response' do
          resp = Faraday::Response.new(body: 'bar', status: 200)
          hsh = { data: 'bar', status: 200 }

          expect(subject.build(response: resp).handle).to eq(hsh)
        end
      end
    end

    context 'when status 404' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Not found', status: 404)
        hsh = { data: { error: true, message: 'We could not find that resource' }, status: resp.status }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end

    context 'when status 403' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Forbidden', status: 403)
        hsh = { data: { error: true, message: 'Forbidden' }, status: resp.status }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end

    context 'when status 401' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Unauthorized', status: 401)
        hsh = { data: { error: true, message: 'Unauthorized' }, status: resp.status }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end

    context 'when status 400' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: { error: true, message: 'Invalid uuid' }, status: 400)
        hsh = { data: { error: true, message: 'Invalid uuid' }, status: resp.status }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end

    context 'when status 500' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Something went wrong', status: 500)
        hsh = { data: { error: true, message: 'Something went wrong' }, status: resp.status }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end
  end
end
