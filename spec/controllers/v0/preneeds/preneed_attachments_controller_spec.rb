# frozen_string_literal: true

require 'rails_helper'
require 'controllers/concerns/form_attachment_create_spec'

RSpec.describe V0::Preneeds::PreneedAttachmentsController, type: :controller do
  it_behaves_like 'a FormAttachmentCreate controller', attachment_factory: :preneed_attachment

  describe '#create' do
    it 'uploads a preneed attachment' do
      post(:create, params: { preneed_attachment: {
             file_data: fixture_file_upload('../preneeds/extras.pdf', 'application/pdf')
           } })

      expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq Preneeds::PreneedAttachment.last.guid
    end
  end
end
