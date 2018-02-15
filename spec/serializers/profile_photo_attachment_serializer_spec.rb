# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProfilePhotoAttachmentSerializer, type: :serializer do
  let(:model) { ::VIC::ProfilePhotoAttachment.new(file_data: file_data.to_json, guid: 'abcd') }
  let(:attributes) { JSON.parse(subject)['data']['attributes'] }

  context 'with an anonymous upload' do
    let(:file_data) { { filename: 'test.jpg', path: 'test_dir' } }
    subject { serialize(model, serializer_class: described_class) }

    it 'should not include the filename and path' do
      expect(attributes['filename']).to be_nil
      expect(attributes['path']).to be_nil
    end
  end

  context 'with an authenticated upload' do
    let(:file_data) { { filename: 'test.jpg', path: 'test_dir', user_uuid: '1234', form_id: '5678' } }

    subject { serialize(model, serializer_class: described_class) }

    it 'should include the filename and path' do
      expect(attributes['filename']).not_to be_nil
      expect(attributes['path']).not_to be_nil
    end
  end
end
