# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::GI::InstitutionsController, type: :controller do
  let(:client) { instance_double('GI::Client') }

  before do
    controller.instance_variable_set(:@client, client)
  end

  describe '#autocomplete' do
    it 'calls client method' do
      controller.instance_variable_set(:@client, client)
      get 'autocomplete', params: { id: '123' }
      expect(client).to have_received(:get_autocomplete_suggestions).with('id' => '123')
    end
  end

  describe '#children' do
    it 'calls client method' do
      controller.instance_variable_set(:@client, client)
      get 'children', params: { id: '123' }
      expect(client).to have_received(:get_institution_children).with('id' => '123')
    end
  end
end
