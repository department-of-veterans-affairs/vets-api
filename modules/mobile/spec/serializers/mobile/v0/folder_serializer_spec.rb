# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::FolderSerializer do
  let(:folder) { build_stubbed(:folder) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(folder, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to eq folder.id.to_s
  end

  it 'includes :folder_id' do
    expect(rendered_attributes[:folder_id]).to eq folder.id
  end

  it 'includes :name' do
    expect(rendered_attributes[:name]).to eq folder.name
  end

  it 'includes :count' do
    expect(rendered_attributes[:count]).to eq folder.count
  end

  it 'includes :unread_count' do
    expect(rendered_attributes[:unread_count]).to eq folder.unread_count
  end

  it 'includes :system_folder' do
    expect(rendered_attributes[:system_folder]).to eq folder.system_folder
  end

  it 'includes :self link' do
    expected_url = Mobile::UrlHelper.new.v0_folder_url(folder.id)
    expect(rendered_hash[:data][:links][:self]).to eq expected_url
  end
end
