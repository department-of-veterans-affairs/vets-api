# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VIC::ProfilePhotoAttachment, type: :model do
  describe '#set_file_data!' do
    context 'with a logged in user' do
      it 'should store the user uuid and the form id' do
        form = create(:in_progress_form, form_id: 'VIC', id: 123)
        attachment = create(:profile_photo_attachment,
                            file_path: 'spec/fixtures/files/va.gif',
                            file_type: 'image/gif',
                            form: form)

        expect(attachment.parsed_file_data['form_id']).to eq(123)
        expect(attachment.parsed_file_data).to have_key('user_uuid')
      end
    end

    context 'with an anonymous user' do
      it 'should not store user uuid and form id or return path and filename' do
        attachment = create(:profile_photo_attachment,
                            file_path: 'spec/fixtures/files/va.gif',
                            file_type: 'image/gif')

        expect(attachment.parsed_file_data).not_to have_key('form_id')
        expect(attachment.parsed_file_data).not_to have_key('user_uuid')
      end
    end
  end

  describe '#get_file' do
    let!(:attachment) do
      create(:profile_photo_attachment,
             file_path: 'spec/fixtures/files/va.gif',
             file_type: 'image/gif')
    end

    it 'should use the new filename to get the file' do
      ProcessFileJob.drain
      expect(attachment.get_file.exists?).to eq(true)
    end
  end
end
