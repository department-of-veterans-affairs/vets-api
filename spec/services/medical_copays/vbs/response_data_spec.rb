# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MedicalCopays::VBS::ResponseData do
  subject { described_class }

  let(:resp) { Faraday::Response.new(body: body, status: status) }
  let(:body) { [{ 'foo_bar' => 'bar' }] }
  let(:status) { 200 }

  describe 'attributes' do
    it 'responds to body' do
      expect(subject.build({ response: resp }).respond_to?(:body)).to be(true)
    end

    it 'responds to status' do
      expect(subject.build({ response: resp }).respond_to?(:status)).to be(true)
    end
  end

  describe '.build' do
    it 'returns an instance of Token' do
      expect(subject.build({ response: resp })).to be_an_instance_of(described_class)
    end
  end

  describe '#handle' do
    context 'when status 200' do
      it 'returns a formatted response' do
        hsh = { data: [{ 'fooBar' => 'bar' }], status: 200 }

        expect(subject.build({ response: resp }).handle).to eq(hsh)
      end

      it 'increments statsD success' do
        expect { subject.build({ response: resp }).handle }.to trigger_statsd_increment('api.mcp.vbs.success')
      end
    end

    context 'when status 404' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Resource not found', status: 404)
        hsh = { data: { message: 'Resource not found' }, status: resp.status }

        expect(subject.build({ response: resp }).handle).to eq(hsh)
      end

      it 'increments statsD failure' do
        resp = Faraday::Response.new(body: 'Resource not found', status: 404)

        expect { subject.build({ response: resp }).handle }.to trigger_statsd_increment('api.mcp.vbs.failure')
      end
    end

    context 'when status 403' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Forbidden', status: 403)
        hsh = { data: { message: 'Forbidden' }, status: resp.status }

        expect(subject.build({ response: resp }).handle).to eq(hsh)
      end

      it 'increments statsD failure' do
        resp = Faraday::Response.new(body: 'Forbidden', status: 403)

        expect { subject.build({ response: resp }).handle }.to trigger_statsd_increment('api.mcp.vbs.failure')
      end
    end

    context 'when status 401' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Unauthorized', status: 401)
        hsh = { data: { message: 'Unauthorized' }, status: resp.status }

        expect(subject.build({ response: resp }).handle).to eq(hsh)
      end

      it 'increments statsD failure' do
        resp = Faraday::Response.new(body: 'Unauthorized', status: 401)

        expect { subject.build({ response: resp }).handle }.to trigger_statsd_increment('api.mcp.vbs.failure')
      end
    end

    context 'when status 400' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: { error: true, message: 'Bad request' }, status: 400)
        hsh = { data: { message: 'Bad request' }, status: resp.status }

        expect(subject.build({ response: resp }).handle).to eq(hsh)
      end

      it 'increments statsD failure' do
        resp = Faraday::Response.new(body: { error: true, message: 'Bad request' }, status: 400)

        expect { subject.build({ response: resp }).handle }.to trigger_statsd_increment('api.mcp.vbs.failure')
      end
    end

    context 'when status 500' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Something went wrong', status: 500)
        hsh = { data: { message: 'Something went wrong' }, status: resp.status }

        expect(subject.build({ response: resp }).handle).to eq(hsh)
      end

      it 'increments statsD failure' do
        resp = Faraday::Response.new(body: 'Something went wrong', status: 500)

        expect { subject.build({ response: resp }).handle }.to trigger_statsd_increment('api.mcp.vbs.failure')
      end
    end
  end

  describe '#transformed_body' do
    let(:status) { 200 }
    let(:body) do
      [
        {
          'ppS_SEQ_NUM' => 0,
          'details' => [{ 'pD_TRANS_DESC_Output' => 0, 'pD_REF_NO' => 0 }],
          'city' => 'string'
        },
        {
          'pH_ICN_NUMBER' => 0,
          'station' => [{ 'cyclE_NUM' => 0, 'lbX_FEDEX_BAR_CDE' => 0 }],
          'state' => 'string'
        }
      ]
    end
    let(:transformed_hsh) do
      [
        {
          'ppSSeqNum' => 0,
          'details' => [{ 'pDTransDescOutput' => 0, 'pDRefNo' => 0 }],
          'city' => 'string'
        },
        {
          'pHIcnNumber' => 0,
          'station' => [{ 'cyclENum' => 0, 'lbXFedexBarCde' => 0 }],
          'state' => 'string'
        }
      ]
    end

    it 'transforms all the keys in an array of hashes' do
      expect(subject.build({ response: resp }).transformed_body).to eq(transformed_hsh)
    end
  end
end
