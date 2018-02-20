# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::VIC::ProfilePhotoAttachmentsDownloadController, type: :controller do
  describe '#show' do
    let(:guid) { ::VIC::ProfilePhotoAttachment.last.guid }

    before do
      ::VIC::ProfilePhotoAttachment.new(file_data: {
        filename: 'test.jpg',
        path: 'anonymous'
      }.to_json).save!
      # post(
      #   :create,
      #   profile_photo_attachment: {
      #     file_data: fixture_file_upload('files/sm_file1.jpg')
      #   }
      # )
    end

    context 'with an anonymous user' do
      it 'fails' do
        get(:show, id: guid)
        expect(response).not_to be_success
      end
    end

    context 'with a logged in user' do
      let(:user) { create(:user, :loa3) }
      let(:file_data) { Random.new.bytes(1024) }

      before do
        expect_any_instance_of(described_class).to receive(:authenticate_token).at_least(:once).and_return(true)
        expect_any_instance_of(CarrierWave::SanitizedFile).to receive(:read).at_least(:once).and_yield(file_data)
      end

      it 'allows retrieval of the file' do
        get(:show, id: guid)
        expect(response).to be_success
        expect(response.headers['Content-Type']).to eq('image/jpeg')
        expect(response.headers).to have_key('Content-Disposition')
      end
    end
  end
end
