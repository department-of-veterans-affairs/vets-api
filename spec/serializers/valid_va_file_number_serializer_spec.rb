# frozen_string_literal: true

require 'rails_helper'

describe ValidVAFileNumberSerializer, type: :serializer do
  subject { serialize(file_number, serializer_class: described_class) }

  let(:file_number) { { file_nbr: true } }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :valid_va_file_number' do
    expect(attributes['valid_va_file_number']).to eq file_number[:file_nbr]
  end
end
