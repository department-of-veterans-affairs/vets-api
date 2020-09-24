# frozen_string_literal: true

require 'rails_helper'
require 'common/models/resource'

describe Common::Resource do
  context 'with a dummy class with two attributes' do
    let(:klass) do
      Class.new Common::Resource do
        attribute :id, Types::Nil.default(nil)
        attribute :message, Types::String
      end
    end

    let(:instance) { klass.new(message: 'foo') }

    it 'can be created with a hash' do
      expect(instance.message).to eq('foo')
    end
  end
end
