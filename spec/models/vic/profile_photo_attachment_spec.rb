# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VIC::ProfilePhotoAttachment, type: :model do
  describe '#set_file_data!' do
    context 'with a logged in user' do
      it 'should store the user uuid and the form id' do
        attachment = create(:profile_photo_attachment,
                            file_path: 'spec/fixtures/files/va.gif',
                            file_type: 'image/gif')

        puts attachment.parsed_file_data
        # expect(attachment.parsed_file_data)
      end
    end

    context 'with an anonymous user' do
      it 'should not store user uuid and form id' do
        attachment = create(:profile_photo_attachment,
                            file_path: 'spec/fixtures/files/va.gif',
                            file_type: 'image/gif')
        puts attachment.parsed_file_data
      end
    end
  end
end
