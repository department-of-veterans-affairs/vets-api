# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Folder do
  describe 'validations on name' do
    subject { described_class.new(params) }

    before { subject.valid? }

    context 'with name set to nil' do
      let(:params) { { name: nil } }

      it 'has errors for presence of name' do
        expect(subject.errors[:name].first).to eq('can\'t be blank')
      end
    end

    context 'with name exceeding 50 characters' do
      let(:params) { { name: 'a' * 51 } }

      it 'has errors for length of name exceeding 50' do
        expect(subject.errors[:name].first).to eq('is too long (maximum is 50 characters)')
      end
    end

    context 'with name having non alphanumeric characters' do
      let(:params) { { name: 'name!' } }

      it 'has errors for not being alphanumeric' do
        expect(subject.errors[:name].first).to eq('is not alphanumeric (letters, numbers, or spaces)')
      end
    end

    context 'with name having control characters' do
      let(:params) { { name: "name \n name" } }

      it 'has errors for illegal characters' do
        expect(subject.errors[:name].first).to eq('contains illegal characters')
      end
    end
  end

  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) { attributes_for(:folder, id: 0) }
    let(:other) { described_class.new(attributes_for(:folder, id: 1)) }

    it 'populates attributes' do
      expect(described_class.attribute_set).to contain_exactly(:id, :name, :count, :unread_count,
                                                               :system_folder, :metadata)
      expect(subject.id).to eq(params[:id])
      expect(subject.name).to eq(params[:name])
      expect(subject.count).to eq(params[:count])
      expect(subject.unread_count).to eq(params[:unread_count])
      expect(subject.system_folder).to eq(params[:system_folder])
    end
  end
end
