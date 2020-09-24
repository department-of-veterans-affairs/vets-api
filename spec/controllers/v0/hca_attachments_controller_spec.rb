# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::HCAAttachmentsController, type: :controller do
  describe '#create' do
    it 'uploads an hca attachment' do
      post(:create, params: { hca_attachment: {
             file_data: fixture_file_upload('pdf_fill/extras.pdf')
           } })
      expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq HCAAttachment.last.guid
      expect(FormAttachment.last).to be_a(HCAAttachment)
    end

    it 'validates input parameters' do
      post(:create)
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)['errors'].first['detail'])
        .to eq('The required parameter "hca_attachment", is missing')
    end

    it 'validates that the upload attachment is not nil' do
      file_data = fixture_file_upload('pdf_fill/extras.pdf')

      post(:create, params: { hca_attachment: {
             file_data: file_data
           } })

      uploaded_file_path =  HCAAttachment.last.get_file.file
      file_1 = File.open(uploaded_file_path).read
      file_2 = File.open(file_data).read

      expect(file_1).to eq(file_2)
    end
  end
end
