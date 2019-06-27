# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::GI::InstitutionsController, type: :controller do
  describe '#children' do
    it 'calls client' do
      client_stub = spy('GI::Client')
      id = 1

      get :children, params: { id: id }

      expect(client_stub).to have_received(:get_institution_children).with(id)

      # post(:create, params: { hca_attachment: {
      #        file_data: fixture_file_upload('pdf_fill/extras.pdf')
      #      } })

      # expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq HcaAttachment.last.guid
    end
  end
end
