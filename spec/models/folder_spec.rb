# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Folder do
  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) { attributes_for(:folder, folder_id: 0) }
    let(:other) { described_class.new(attributes_for(:folder, folder_id: 1)) }

    it 'populates attributes' do
      expect(described_class.attribute_set.map(&:name)).to contain_exactly(:folder_id, :name, :count, :unread_count,
                                                                           :system_folder)
      expect(subject.folder_id).to eq(params[:folder_id])
      expect(subject.name).to eq(params[:name])
      expect(subject.count).to eq(params[:count])
      expect(subject.unread_count).to eq(params[:unread_count])
      expect(subject.system_folder).to eq(params[:system_folder])
    end

    it 'can be compared by name' do
      expect(subject <=> other).to eq(-1)
      expect(other <=> subject).to eq(1)
    end
  end
end
