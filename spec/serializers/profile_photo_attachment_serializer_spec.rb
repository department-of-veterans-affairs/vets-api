# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProfilePhotoAttachmentSerializer, type: :serializer do
  let(:anon_attributes) do
    { filename: 'test.jpg', path: 'test_dir' }
  end

  let(:auth_attributes) do
    anon_attributes.merge(user_uuid: '1234', form_id: '5678')
  end

  let(:data) { JSON.parse(subject) }

  context 'with an anonymous upload' do
    let(:model) { ::VIC::ProfilePhotoAttachment.new(file_data: anon_attributes.to_json, guid: 'abcd') }

    subject { serialize(model, serializer_class: described_class) }

    it 'should not include the filename and path' do
      expect(data['filename']).to be_nil
      expect(data['path']).to be_nil
    end
  end

  context 'with an authenticated upload' do
    let(:model) { ::VIC::ProfilePhotoAttachment.new(file_data: auth_attributes.to_json, guid: 'abcd') }

    subject { serialize(model, serializer_class: described_class) }

    it 'should include the filename and path' do
      expect(data['filename']).not_to be_nil
      expect(data['path']).not_to be_nil
    end
  end
end
