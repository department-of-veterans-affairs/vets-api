# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessFileJob do
  describe '#perform' do
    it 'should save the new processed file and delete the old file' do
      profile_photo_attachment = build(:profile_photo_attachment)
      parsed_file_data = profile_photo_attachment.parsed_file_data
      ProcessFileJob.new.perform(
        parsed_file_data['path'],
        parsed_file_data['filename']
      )
      expect(profile_photo_attachment.get_file.exists?).to eq(true)

      # check old file deleted
      form_id = parsed_file_data['form_id']
      attachment_uploader = profile_photo_attachment.send(:get_attachment_uploader, form_id)

      attachment_uploader.retrieve_from_store!(
        parsed_file_data['filename']
      )
      expect(attachment_uploader.file.exists?).to eq(false)
    end
  end
end
