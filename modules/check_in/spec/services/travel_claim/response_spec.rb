# frozen_string_literal: true

require 'rails_helper'

describe TravelClaim::Response do
  subject { described_class }

  describe '#handle' do
    context 'when status 200' do
      context 'when json string' do
        it 'returns a formatted response' do
          claims_api_response = { value: { claimNumber: 'TC202207000011666' }, formatters: [], contentTypes: [],
                                  declaredType: [], statusCode: 200 }
          resp = Faraday::Response.new(body: claims_api_response, status: 200)
          hsh = { data: claims_api_response, status: 200 }

          expect(subject.build(response: resp).handle).to eq(hsh)
        end
      end

      context 'when non json string' do
        it 'returns a formatted response' do
          claims_api_response = 'TC202207000011666'
          resp = Faraday::Response.new(body: claims_api_response, status: 200)
          hsh = { data: claims_api_response, status: 200 }

          expect(subject.build(response: resp).handle).to eq(hsh)
        end
      end
    end

    context 'when status 400 for already submitted claim' do
      it 'returns a formatted response' do
        error_message = '10/16/2020 : This appointment already has a claim associated with it.'
        claims_api_400_response = {
          currentDate: '[10/16/2020 03:28:48 PM]',
          message: error_message
        }
        resp = Faraday::Response.new(body: claims_api_400_response, status: 400)
        hsh = { data: { error: true, message: error_message }, status: resp.status }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end

    context 'when status 400 for multiple appointments' do
      it 'returns a formatted response' do
        error_message = '10/16/2020 : There were multiple appointments for that date'
        claims_api_400_response = {
          currentDate: '[10/16/2020 03:28:48 PM]',
          message: error_message
        }
        resp = Faraday::Response.new(body: claims_api_400_response, status: 400)
        hsh = { data: { error: true, message: error_message }, status: resp.status }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end

    context 'when status 500' do
      it 'returns a formatted response' do
        resp = Faraday::Response.new(body: 'Something went wrong', status: 500)
        hsh = { data: { error: true, message: 'Claim submission failed' }, status: resp.status }

        expect(subject.build(response: resp).handle).to eq(hsh)
      end
    end
  end
end
