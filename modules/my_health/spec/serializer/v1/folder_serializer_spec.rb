# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::FolderSerializer, type: :serializer do
  subject { serialize(folder, serializer_class: described_class) }

  let(:folder) { build_stubbed(:folder) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes :id' do
    expect(data['id']).to eq folder.id.to_s
  end

  it 'includes :folder_id' do
    expect(attributes['folder_id']).to eq folder.id
  end

  it 'includes :name' do
    expect(attributes['name']).to eq folder.name
  end

  it 'includes :count' do
    expect(attributes['count']).to eq folder.count
  end

  it 'includes :unread_count' do
    expect(attributes['unread_count']).to eq folder.unread_count
  end

  it 'includes :system_folder' do
    expect(attributes['system_folder']).to eq folder.system_folder
  end

  it 'includes :self link' do
    expected_url = MyHealth::UrlHelper.new.v1_folder_url(folder.id)
    expect(links['self']).to eq expected_url
  end
end
