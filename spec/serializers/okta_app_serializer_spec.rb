# frozen_string_literal: true

require 'rails_helper'

describe OktaAppSerializer, type: :serializer do
  subject { serialize(app_from_grant, serializer_class: described_class) }

  let(:app_from_grant) do
    {
      'id' => '0oa2ey2m6kEL2897N2p7',
      'type' => 'lighthouse_consumer_app',
      'attributes' => {
        'title' => 'someLabel1',
        'logo' => 'logoName',
        'privacyUrl' => '',
        'grants' => [
          { 'title' => 'Read Claim Information', 'id' => '', 'created' => '2024-01-11T18:58:61.000Z' },
          { 'title' => 'Submit Claims', 'id' => '', 'created' => '2024-01-15T18:52:61.000Z' }
        ]
      }
    }
  end

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq app_from_grant['id']
  end

  it 'includes :title' do
    expect(attributes['title']).to eq app_from_grant['attributes']['title']
  end

  it 'includes :logo' do
    expect(attributes['logo']).to eq app_from_grant['attributes']['logo']
  end

  it 'includes :privacy_url' do
    expect(attributes['privacy_url']).to eq app_from_grant['attributes']['privacy_url']
  end

  it 'includes :grants' do
    expect(attributes['grants']).to eq app_from_grant['attributes']['grants']
  end
end
