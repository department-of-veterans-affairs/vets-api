# frozen_string_literal: true
require 'rails_helper'

RSpec.describe LetterSerializer, type: :serializer do
  include SchemaMatchers

  let(:letter) { build :letter }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  subject { serialize(letter, serializer_class: described_class) }

  it 'should include name' do
    puts subject
    expect(attributes['name']).to eq(letter.name)
  end

  it 'should include the letter type' do
    expect(attributes['letter_type']).to eq(letter.letter_type)
  end

  it 'should match the letter schema' do
    expect(subject).to match_schema('letter')
  end

  it 'does a collection' do
    letter1 = Letter.new('one', 'BENEFITSUMMARY')
    letter2 = Letter.new('two', 'BENEFITSUMMARYDEPENDENT')
    a = [letter1, letter2]
    s = ActiveModel::Serializer::CollectionSerializer.new(a, each_serializer: LetterSerializer)
    puts s
  end
end
