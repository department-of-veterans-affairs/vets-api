# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PreneedsAttachmentTypeSerializer, type: :serializer do
  let(:attachment_type) { build :preneeds_attachment_type }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  subject { serialize(attachment_type, serializer_class: described_class) }

  it 'should include id' do
    expect(data['id'].to_i).to eq(attachment_type.id)
  end

  it 'should include the preneeds_attachment_type_id' do
    expect(attributes['attachment_type_id']).to eq(attachment_type.id)
  end

  it 'should include the description' do
    expect(attributes['description']).to eq(attachment_type.description)
  end
end
