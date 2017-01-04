# frozen_string_literal: true
require 'rails_helper'
require 'hca/service'

RSpec.describe 'Health Care Application Integration', type: [:request, :serializer] do
  describe 'GET healthcheck' do
    subject do
      get(v0_health_care_application_healthcheck_url)
    end
    let(:body) { { 'up' => true } }
    let(:es_stub) { double(health_check: { up: true }) }

    it 'should call ES' do
      allow(HCA::Service).to receive(:new) { es_stub }
      subject
      expect(JSON.parse(response.body)).to eq(body)
    end
  end

  describe 'POST create' do
    subject do
      post(
        v0_health_care_application_url,
        params.to_json,
        'CONTENT_TYPE' => 'application/json',
        'HTTP_X_KEY_INFLECTION' => 'camel'
      )
    end

    context 'with valid params' do
      let(:params) do
        {
          form: {
            summary: {
              personInfo: {
                firstName: 'William'
              }.to_json
            }
          }
        }
      end

      it 'should render success' do
        subject
        expect(JSON.parse(response.body)['success']).to eq(true)
      end
    end

    context 'with invalid params' do
      let(:params) do
        {}
      end

      it 'should render failure' do
        subject
        expect(JSON.parse(response.body)['success']).to eq(false)
      end
    end
  end
end
