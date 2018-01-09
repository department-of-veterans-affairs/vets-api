# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReceiveApplicationSerializer, type: :serializer do
  let(:receive_application) { build :receive_application }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  subject { serialize(receive_application, serializer_class: described_class) }

  it 'should include id' do
    expect(data['id']).to eq(receive_application.receive_application_id)
  end

  it 'should include tracking_number as attribute' do
    expect(attributes['tracking_number']).to eq(receive_application.tracking_number)
  end

  it 'should include submitted_at as attribute' do
    expect(attributes['submitted_at']).to eq(receive_application.submitted_at.iso8601(3))
  end

  it 'should include return_code as attribute' do
    expect(attributes['return_code']).to eq(receive_application.return_code)
  end

  it 'should include application_uuid as attribute' do
    expect(attributes['application_uuid']).to eq(receive_application.application_uuid)
  end

  it 'should include return_description as attribute' do
    expect(attributes['return_description']).to eq(receive_application.return_description)
  end
end
