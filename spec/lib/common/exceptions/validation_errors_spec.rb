# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::ValidationErrors do
  class FakeModel
    include ActiveModel::Validations
    validates_presence_of :attr_1, :attribute2
    attr_accessor :attr_1, :attribute2
  end

  let(:resource) { FakeModel.new }

  context 'with no resource provided' do
    it do
      expect { described_class.new }
        .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
    end
  end

  context 'with resource that has no errors provided' do
    it do
      expect { described_class.new(resource) }
        .to raise_error(TypeError, 'the resource provided has no errors')
    end
  end

  context 'with resource having errors provided' do
    let(:resource_with_errors) do
      resource.valid?
      resource
    end
    subject { described_class.new(resource_with_errors) }

    it 'implements #errors which returns an array' do
      expect(subject.errors).to be_an(Array)
    end

    it 'the first errors object to have relevant keys' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Attr 1 can\'t be blank',
               detail: 'attr-1 - can\'t be blank',
               source: { pointer: 'data/attributes/attr-1' },
               code: '100',
               status: '422')
    end

    it 'the second errors object to have relevant keys' do
      expect(subject.errors.last.to_hash)
        .to eq(title: 'Attribute2 can\'t be blank',
               detail: 'attribute2 - can\'t be blank',
               source: { pointer: 'data/attributes/attribute2' },
               code: '100',
               status: '422')
    end
  end
end
