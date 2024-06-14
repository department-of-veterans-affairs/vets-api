# frozen_string_literal: true

require 'rails_helper'

describe HCARatingInfoSerializer, type: :serializer do
  subject { serialize(rating_info, serializer_class: described_class) }

  let(:rating_info) { { user_percent_of_disability: 1 } }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :user_percent_of_disability' do
    expect(attributes['user_percent_of_disability']).to eq rating_info[:user_percent_of_disability]
  end

end
