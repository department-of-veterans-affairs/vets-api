# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MedicalCopays::VBS::ResponseData do
  subject { described_class }

  describe 'attributes' do
    it 'responds to body' do
      expect(subject.build({}).respond_to?(:body)).to be(true)
    end

    it 'responds to status' do
      expect(subject.build({}).respond_to?(:status)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of Token' do
      expect(subject.build).to be_an_instance_of(described_class)
    end
  end

  describe '#handle' do
    context 'when status 200' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: { foo: 'bar' }, status: 200)
        hsh = { data: { foo: 'bar' }, status: 200 }

        expect(subject.build({ response: resp }).handle).to eq(hsh)
      end
    end

    context 'when status 404' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Resource not found', status: 404)
        hsh = { data: { message: 'Resource not found' }, status: resp.status }

        expect(subject.build({ response: resp }).handle).to eq(hsh)
      end
    end

    context 'when status 403' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Forbidden', status: 403)
        hsh = { data: { message: 'Forbidden' }, status: resp.status }

        expect(subject.build({ response: resp }).handle).to eq(hsh)
      end
    end

    context 'when status 401' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Unauthorized', status: 401)
        hsh = { data: { message: 'Unauthorized' }, status: resp.status }

        expect(subject.build({ response: resp }).handle).to eq(hsh)
      end
    end

    context 'when status 400' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: { error: true, message: 'Bad request' }, status: 400)
        hsh = { data: { message: 'Bad request' }, status: resp.status }

        expect(subject.build({ response: resp }).handle).to eq(hsh)
      end
    end

    context 'when status 500' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Something went wrong', status: 500)
        hsh = { data: { message: 'Something went wrong' }, status: resp.status }

        expect(subject.build({ response: resp }).handle).to eq(hsh)
      end
    end
  end
end
