# frozen_string_literal: true
require 'rails_helper'

RSpec.describe LetterSerializer, type: :serializer do
  include SchemaMatchers

  let(:letter) { build :letter }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  subject { serialize(letter, serializer_class: described_class) }

  it 'should include name' do
    expect(attributes['name']).to eq(letter.name)
  end

  it 'should include the letter type' do
    expect(attributes['letter_type']).to eq(letter.letter_type)
  end

  it 'should match the letter schema' do
    expect(subject).to match_schema('letter')
  end
end
