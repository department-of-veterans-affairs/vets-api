# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::GI::InstitutionsController, type: :controller do
  let(:client) { instance_double('GI::Client') }
  describe '#children' do
    it 'calls client' do
      # client_response = client.get_zipcode_rate(id: '20001')
      # client_stub = spy('GI::Client')
      # client = double('GI::Client')
      # allow(GI::Client).to receive(:get_institution_children)

      allow(client).to receive(:get_institution_children)
      get 'children', params: { id: 'ccp_12345' }

      expect(response.content_type).to eq(nil)

      expect(client).to have_received(:get_institution_children)
    end
  end
end
