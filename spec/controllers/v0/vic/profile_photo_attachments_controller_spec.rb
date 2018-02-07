# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::VIC::ProfilePhotoAttachmentsController, type: :controller do
  describe '#create' do
    context 'with an anonymous user' do
      it 'uploads a profile photo attachment' do
        post(
          :create,
          profile_photo_attachment: {
            file_data: fixture_file_upload('files/sm_file1.jpg')
          }
        )

        puts response.body
        data = JSON.parse(response.body)['data']['attributes']

        expect(data).to have_key('filename')
        expect(data['path']).to eq 'profile_photo_attachments/anonymous'
      end
    end

    context 'with logged in user' do
      let(:user) { create(:user, :loa3) }

      before do
        controller.instance_variable_set(:@current_user, user)
        puts user.uuid
      end

      it 'uploads a profile photo attachment' do
        before_count = InProgressForm.count

        post(
          :create,
          profile_photo_attachment: {
            file_data: fixture_file_upload('files/sm_file1.jpg')
          }
        )

        puts response.body
        data = JSON.parse(response.body)['data']['attributes']

        expect(data).to have_key('filename')
        expect(data['path']).to eq "profile_photo_attachments/#{InProgressForm.last.id}"
        expect(InProgressForm.count).not_to eq(before_count)
      end
    end
  end
end
