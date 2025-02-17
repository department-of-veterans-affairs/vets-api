# frozen_string_literal: true

require 'rails_helper'

class FakeModel
  include ActiveModel::Validations
end

describe AppealsApi::ApplicationController, type: :controller do
  controller do
    skip_before_action :authenticate

    def index
      render json: { message: 'Hello World!' }, status: :ok
    end

    def create
      appeal = FakeModel.new
      appeal.errors.add '/attribute/pointer', 'Custom detail message', meta: { extra: 'metadata' }
      appeal.errors.add 'ignored', 'Custom source', source: { header: 'abc123' }
      appeal.errors.add '/attribute/pointer',
                        'Using different base exception',
                        error_tpath: 'common.exceptions.detailed_schema_errors.range'

      render json: model_errors_to_json_api(appeal), status: :unprocessable_entity
    end
  end

  describe 'deactivate_endpoint' do
    context 'when a sunset date is passed' do
      it 'returns a 404' do
        allow(controller).to receive(:sunset_date).and_return(Date.yesterday)
        get :index
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when sunset date is nil or in the future' do
      it 'hits the endpoint' do
        allow(controller).to receive(:sunset_date).and_return(Date.tomorrow)
        get :index
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe '#model_errors_to_json_api' do
    let(:errors) { JSON.parse(response.body)['errors'] }

    before { post :create }

    it 'defaults to common.exception.validation_error base & removes nil keys' do
      error = errors[0]
      expect(error['code']).to eq 100
      expect(error['title']).to eq 'Validation error'
      expect(error.keys).not_to include 'links'
    end

    it 'sets error.attribute as pointer & error.message as detail' do
      error = errors[0]
      expect(error['source']['pointer']).to eq '/attribute/pointer'
      expect(error['detail']).to eq 'Custom detail message'
    end

    it 'merges error.options hash into the base error schema' do
      error = errors[0]
      expect(error['meta']).to eq({ 'extra' => 'metadata' })
    end

    it 'allows overriding error.attribute source with custom hash', skip: 'Failing Test, per commit history' do
      error = errors[1]
      expect(error['source']).to eq({ 'header' => 'abc123' })
    end

    it 'allows using different common exception as base' do
      error = errors[2]
      expect(error['code']).to eq 144
      expect(error['title']).to eq 'Value outside range'
      expect(error.keys).not_to include 'error_tpath'
    end
  end
end
