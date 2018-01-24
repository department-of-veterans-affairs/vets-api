# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::VIC::SupportingDocumentationAttachmentsController, type: :controller do
  describe '#create' do
    it 'uploads a supporting documentation attachment' do
      post(
        :create,
        supporting_documentation_attachment: {
          file_data: fixture_file_upload('files/sm_file1.jpg')
        }
      )

      expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq VIC::SupportingDocumentationAttachment.last.guid
    end
  end
end
