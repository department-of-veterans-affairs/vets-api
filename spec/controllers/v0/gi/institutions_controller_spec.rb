# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::GI::InstitutionsController, type: :controller do
  let(:client) { instance_double('GI::Client') }

  describe '#autocomplete' do
    it 'calls client method' do
      allow(client).to receive(:get_autocomplete_suggestions)
      controller.instance_variable_set(:@client, client)
      get 'autocomplete', params: { id: '123' }
      expect(client).to have_received(:get_autocomplete_suggestions).with('id' => '123')
    end
  end

  describe '#search' do
    it 'calls client method' do
      allow(client).to receive(:get_search_results)
      controller.instance_variable_set(:@client, client)
      get 'search', params: { id: '123' }
      expect(client).to have_received(:get_search_results).with('id' => '123')
    end
  end

  describe '#show' do
    it 'calls client method' do
      allow(client).to receive(:get_institution_details)
      controller.instance_variable_set(:@client, client)
      get 'show', params: { id: '123' }
      expect(client).to have_received(:get_institution_details).with('id' => '123')
    end
  end

  describe '#children' do
    it 'calls client method' do
      allow(client).to receive(:get_institution_children)
      controller.instance_variable_set(:@client, client)
      get 'children', params: { id: '123' }
      expect(client).to have_received(:get_institution_children).with('id' => '123')
    end
  end

  describe 'institutions' do
    {
      'autocomplete' => :get_autocomplete_suggestions,
      'search' => :get_search_results,
      'show' => :get_institution_details,
      'children' => :get_institution_children
    }.each do |controller_method, client_method|
      it "#{controller_method} calls client method #{client_method}" do
        allow(client).to receive(client_method)
        get controller_method, params: { id: '123', format: 'json' }
        expect(client).to have_received(client_method).with('id' => '123')
      end
    end
  end
end
