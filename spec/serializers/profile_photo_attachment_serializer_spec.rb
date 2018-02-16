# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProfilePhotoAttachmentSerializer, type: :serializer do
  let(:file_data) { { filename: 'test.jpg', path: 'test_dir' } }
  let(:model) { ::VIC::ProfilePhotoAttachment.new(file_data: file_data.to_json, guid: 'abcd') }

  let(:attributes) { JSON.parse(subject)['data']['attributes'] }

  subject { serialize(model, serializer_class: described_class) }

  it 'should serialize the filename and path out of file_data' do
    expect(attributes['filename']).to eq('test.jpg')
    expect(attributes['path']).to eq('test_dir')
  end
end
