# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::VIC::PhotoAttachmentsController, type: :controller do
  describe '#create' do
    it 'uploads a photo id attachment' do
      post(
        :create,
        photo_attachment: {
          file_data: fixture_file_upload('files/sm_file1.jpg')
        }
      )

      expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq VIC::PhotoAttachment.last.guid
    end
  end
end
