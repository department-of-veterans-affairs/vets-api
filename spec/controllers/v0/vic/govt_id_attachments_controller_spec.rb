# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::VIC::GovtIdAttachmentsController, type: :controller do
  describe '#create' do
    it 'uploads a govt id attachment' do
      post(
        :create,
        govt_id_attachment: {
          file_data: fixture_file_upload('files/sm_file1.jpg')
        }
      )

      expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq VIC::GovtIdAttachment.last.guid
    end
  end
end
