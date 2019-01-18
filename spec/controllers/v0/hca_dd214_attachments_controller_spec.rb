# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::HcaDd214AttachmentsController, type: :controller do
  describe '#create' do
    it 'uploads an hca dd214 attachment' do
      post(
        :create,
        hca_dd214_attachment: {
          file_data: fixture_file_upload('pdf_fill/extras.pdf')
        }
      )

      expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq HcaDd214Attachment.last.guid
    end
  end
end
