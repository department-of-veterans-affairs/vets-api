# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessFileJob do
  describe '#perform' do
    it 'should save the new processed file and delete the old file' do
      profile_photo_attachment = build(:profile_photo_attachment)
      ProcessFileJob.new.perform(
        profile_photo_attachment.parsed_file_data['path'],
        profile_photo_attachment.parsed_file_data['filename']
      )
      # TOOD finish
    end
  end
end
