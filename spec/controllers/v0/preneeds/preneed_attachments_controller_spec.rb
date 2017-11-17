# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::Preneeds::PreneedAttachmentsController, type: :controller do
  describe '#create' do
    it 'uploads a preneed attachment' do
      post(
        :create,
        preneed_attachment: {
          file_data: fixture_file_upload('pdf_fill/extras.pdf')
        }
      )

      expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq Preneeds::PreneedAttachment.last.guid
    end
  end
end
