# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::HcaAttachmentsController, type: :controller do
  describe '#create' do
    it 'uploads an hca attachment' do
      post(:create, params: { hca_attachment: {
             file_data: fixture_file_upload('pdf_fill/extras.pdf')
           } })

      expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq HcaAttachment.last.guid
    end

    it 'validates input parameters' do
      post(:create)
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('The required parameter "hca_attachment", is missing')
    end
  end
end
