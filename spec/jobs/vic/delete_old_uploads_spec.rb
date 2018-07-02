# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VIC::DeleteOldUploads do
  describe '#get_uuids' do
    it 'should get uuids from form data' do
      expect(described_class.new.get_uuids(build(:vic_submission).parsed_form)).to eq(
        [
          VIC::ProfilePhotoAttachment.last.guid,
          VIC::SupportingDocumentationAttachment.last.guid
        ]
      )
    end
  end
end
