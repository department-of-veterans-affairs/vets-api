# frozen_string_literal: true

require 'rails_helper'

describe LettersSerializer, type: :serializer do
  subject { serialize(letters_response, serializer_class: described_class) }

  let(:full_name) { 'MARK WEBB' }
  let(:letter) do
    {
      'name' => 'Proof of Creditable Prescription Drug Coverage Letter',
      'letter_type' => 'medicare_partd'
    }
  end

  let(:letters_response) do
    body = { 'letter_destination' => { 'full_name' => full_name }, 'letters' => [letter] }
    response = double('response', body:)
    EVSS::Letters::LettersResponse.new(200, response)
  end

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :full_name' do
    expect(attributes['full_name']).to eq full_name
  end

  it 'includes :letters' do
    expect(attributes['letters'].size).to eq 1
  end

  it 'includes :letters with attributes' do
    expected_attributes = letter.keys.map(&:to_s)
    expect(attributes['letters'].first.keys).to eq expected_attributes
  end
end
