# frozen_string_literal: true

require 'rails_helper'
require 'vets/model'
require 'vets/model/dirty'

RSpec.describe Vets::Model::Dirty do
  let(:user_class) do
    Class.new do
      include Vets::Model

      attr_accessor :name, :email

      def self.attribute_set
        %i[name email]
      end
    end
  end

  let(:user) { user_class.new(name: 'Alice', email: 'alice@example.com') }

  describe '#changed?' do
    it 'returns false when no changes have been made' do
      expect(user.changed?).to be(false)
    end

    it 'returns true when an attribute has been changed' do
      user.name = 'Bob'
      expect(user.changed?).to be(true)
    end

    it 'returns false when changes are reverted back to original values' do
      user.name = 'Bob'
      user.name = 'Alice'
      expect(user.changed?).to be(false)
    end
  end

  describe '#changed' do
    it 'returns an empty array when no changes have been made' do
      expect(user.changed).to eq([])
    end

    it 'returns a list of changed attributes when changes have been made' do
      user.name = 'Bob'
      expect(user.changed).to eq(['name'])
    end

    it 'returns a list of all changed attributes after multiple changes' do
      user.name = 'Bob'
      user.email = 'bob@example.com'
      expect(user.changed).to match_array(%w[name email])
    end
  end

  describe '#changes' do
    it 'returns an empty hash when no changes have been made' do
      expect(user.changes).to eq({})
    end

    it 'returns the changes with the original and current values when an attribute has been changed' do
      user.name = 'Bob'
      expect(user.changes).to eq({ 'name' => %w[Alice Bob] })
    end

    it 'returns changes for multiple attributes' do
      user.name = 'Bob'
      user.email = 'bob@example.com'
      expect(user.changes).to include('name' => %w[Alice Bob])
      expect(user.changes).to include('email' => ['alice@example.com', 'bob@example.com'])
    end

    it 'returns an empty hash if changes are reverted' do
      user.name = 'Bob'
      user.name = 'Alice'
      expect(user.changes).to eq({})
    end
  end
end
