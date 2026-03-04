# frozen_string_literal: true

require 'rails_helper'
require 'digital_forms_api/service/forms'

RSpec.describe DigitalFormsApi::Service::Forms do
  let(:service) { described_class.new }
  let(:form_id) { '21-686c' }
  let(:cache_key) { described_class.template_cache_key(form_id) }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe '#template' do
    context 'when template is not cached' do
      it 'performs a GET request to the forms endpoint' do
        expect(service).to receive(:perform).with(:get, "forms/#{form_id}/template", {}, {})
        service.template(form_id)
      end

      it 'caches the response' do
        response = { 'template' => 'data' }
        allow(service).to receive(:perform).and_return(response)

        service.template(form_id)

        cached_response = Rails.cache.read(cache_key)
        expect(cached_response).to eq(response)
      end

      it 'returns the response from the API' do
        response = { 'template' => 'data' }
        allow(service).to receive(:perform).and_return(response)

        result = service.template(form_id)

        expect(result).to eq response
      end
    end

    context 'when template is called twice' do
      it 'only calls the upstream service once' do
        response = { 'template' => 'data' }
        expect(service).to receive(:perform)
          .with(:get, "forms/#{form_id}/template", {}, {})
          .once
          .and_return(response)

        first_result  = service.template(form_id)
        second_result = service.template(form_id)

        expect(first_result).to eq(response)
        expect(second_result).to eq(response)
      end
    end

    context 'when template is cached' do
      it 'returns the cached response without making an API request' do
        cached_response = { 'template' => 'cached_data' }
        Rails.cache.write(cache_key, cached_response)

        expect(service).not_to receive(:perform)

        result = service.template(form_id)

        expect(result).to eq(cached_response)
      end
    end
  end
end
