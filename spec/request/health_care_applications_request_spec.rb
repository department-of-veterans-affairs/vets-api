# frozen_string_literal: true
require 'rails_helper'
require 'hca/service'

RSpec.describe 'Health Care Application Integration', type: [:request, :serializer] do
  describe 'GET healthcheck' do
    subject do
      get(healthcheck_v0_health_care_applications_path)
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
        v0_health_care_applications_path,
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
        allow_any_instance_of(HCA::Service).to receive(:post).and_return(true)
        subject
        expect(JSON.parse(response.body)['success']).to eq(true)
      end

      context 'with a SOAP error' do
        before do
          allow_any_instance_of(HCA::Service).to receive(:post) do
            raise SOAP::Errors::HTTPError, 'error message'
          end
        end

        it 'should render error message' do
          subject

          expect(response.code).to eq('400')
          expect(JSON.parse(response.body)).to eq(
            {"errors"=>[{"title"=>"Operation failed", "detail"=>"error message", "code"=>"VA900", "status"=>"400"}]}
          )
        end
      end
    end
  end
end
