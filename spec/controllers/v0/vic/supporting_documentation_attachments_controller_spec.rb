# frozen_string_literal: true

require 'rails_helper'
require 'controllers/concerns/form_attachment_create_spec'

RSpec.describe V0::VIC::SupportingDocumentationAttachmentsController, type: :controller do
  it_behaves_like 'a FormAttachmentCreate controller', attachment_factory: :supporting_documentation_attachment

  describe '#create' do
    it 'uploads a supporting documentation attachment' do
      post(:create, params: { supporting_documentation_attachment: {
             file_data: fixture_file_upload('sm_file1.jpg')
           } })

      expect(
        JSON.parse(response.body)['data']['attributes']['guid']
      ).to eq VIC::SupportingDocumentationAttachment.last.guid
    end
  end
end
