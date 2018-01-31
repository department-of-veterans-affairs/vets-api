# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::VIC::ProfilePhotoAttachmentsController, type: :controller do
  describe '#create' do
    it 'uploads a profile photo attachment' do
      post(
        :create,
        profile_photo_attachment: {
          file_data: fixture_file_upload('files/sm_file1.jpg')
        }
      )

      expect(
        JSON.parse(response.body)['data']['attributes']['guid']
      ).to eq VIC::ProfilePhotoAttachment.last.guid
    end
  end
end
