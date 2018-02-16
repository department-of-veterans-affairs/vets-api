# frozen_string_literal: true

require 'rails_helper'
require 'support/authenticated_session_helper'

RSpec.describe V0::VIC::ProfilePhotoAttachmentsController, type: :controller do
  describe '#show' do
    let(:data) { JSON.parse(response.body) }
    let(:guid) { ::VIC::ProfilePhotoAttachment.last.guid }

    before do
      ::VIC::ProfilePhotoAttachment.new(
        file_data: {
          filename: 'test.jpg',
          path: 'anonymous'
        }.to_json
      ).save!
    end

    context 'with an anonymous user' do
      it 'does not allow retrieval of filename and path' do
        get(:show, id: guid)
        expect(response).not_to be_success
      end
    end

    context 'with a logged in user' do
      let(:user) { create(:user, :loa3) }

      before do
        expect_any_instance_of(described_class).to receive(:authenticate_token).at_least(:once).and_return(true)
      end

      it 'allows retrieval of filename and path' do
        get(:show, id: guid)
        puts data
      end
    end
  end

  describe '#create' do
    let(:data) { JSON.parse(response.body)['data']['attributes'] }

    context 'with an anonymous user' do
      it 'uploads a profile photo attachment' do
        post(
          :create,
          profile_photo_attachment: {
            file_data: fixture_file_upload('files/sm_file1.jpg')
          }
        )

        expect(data).to have_key('filename')
        expect(data['path']).to eq 'profile_photo_attachments/anonymous'
      end
    end

    context 'with logged in user' do
      let(:user) { create(:user, :loa3) }

      before do
        controller.instance_variable_set(:@current_user, user)
      end

      it 'uploads a profile photo attachment' do
        before_count = InProgressForm.count

        post(
          :create,
          profile_photo_attachment: {
            file_data: fixture_file_upload('files/sm_file1.jpg')
          }
        )

        expect(data).to have_key('filename')
        expect(data['path']).to eq "profile_photo_attachments/#{InProgressForm.last.id}"
        expect(InProgressForm.count).not_to eq(before_count)
      end
    end
  end
end
