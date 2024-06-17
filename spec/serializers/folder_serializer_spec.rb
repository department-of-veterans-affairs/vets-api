# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FolderSerializer do
  subject { serialize(folder, serializer_class: described_class) }

  let(:folder) { build_stubbed(:folder) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes id' do
    expect(data['id'].to_i).to eq(folder.id)
  end

  it 'includes id as attribute' do
    expect(attributes['folder_id']).to eq(folder.id)
  end

  it "includes the folder's name" do
    expect(attributes['name']).to eq(folder.name)
  end

  it "includes the folders's message count" do
    expect(attributes['count']).to eq(folder.count)
  end

  it "includes the folders's unread message count" do
    expect(attributes['unread_count']).to eq(folder.unread_count)
  end

  it "includes the folders's system folder attribute" do
    expect(attributes['system_folder']).to eq(folder.system_folder)
  end

  it 'includes :self link' do
    expect(links['self']).to eq(v0_folder_url(folder.id))
  end
end
