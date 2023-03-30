# frozen_string_literal: true

require 'rails_helper'

class Validatable
  include ActiveModel::Model
  include ActiveModel::Validations

  attr_accessor :name

  validates :name, folder_name_convention: true
end

describe FolderNameConventionValidator do
  subject { Validatable.new(name:) }

  let(:name) { nil }

  context 'without name' do
    it 'is valid' do
      expect(subject).to be_valid
    end
  end

  context 'with valid name' do
    let(:name) { '1 ab C2349 asZ' }

    it 'is valid' do
      expect(subject).to be_valid
    end
  end

  context 'with another valid name' do
    let(:name) { 'a valid name 123' }

    it 'is valid' do
      expect(subject).to be_valid
    end
  end

  context 'with blank name' do
    let(:name) { '' }

    it 'is invalid' do
      expect(subject).not_to be_valid
    end
  end

  context 'with invalid characters' do
    let(:name) { 'abcde 123 !&^@#abc' }

    it 'is invalid' do
      expect(subject).not_to be_valid
    end
  end

  context 'with tabs' do
    let(:name) { "abcd \t asds" }

    it 'is invalid' do
      expect(subject).not_to be_valid
    end
  end

  context 'with new lines' do
    let(:name) { "abcd \n abcd" }

    it 'is invalid' do
      expect(subject).not_to be_valid
    end
  end
end
