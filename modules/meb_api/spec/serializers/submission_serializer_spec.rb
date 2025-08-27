# frozen_string_literal: true

require 'rails_helper'

describe SubmissionSerializer, type: :serializer do
  subject { serialize(object, serializer_class: described_class) }

  let(:object) { OpenStruct.new(education_benefit: { '@type': 'Chapter33' }) }

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'returns a blank id' do
    expect(data['id']).to eq('')
  end

  it 'serializes the education_benefit attribute' do
    expect(attributes['education_benefit']).to eq({ '@type' => 'Chapter33' })
  end
end
