# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::GI::InstitutionsController, type: :controller do
  describe '#children' do
    it 'calls client' do
      client_stub = instance_double('GI::Client')

      expect(client_stub).to eq(nil)

      # post(:create, params: { hca_attachment: {
      #        file_data: fixture_file_upload('pdf_fill/extras.pdf')
      #      } })

      # expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq HcaAttachment.last.guid
    end
  end
end
