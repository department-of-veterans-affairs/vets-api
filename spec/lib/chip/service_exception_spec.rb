# frozen_string_literal: true

require 'rails_helper'
require 'chip/service_exception'

describe Chip::ServiceException do
  subject { described_class.new(key:) }

  let(:key) { nil }

  describe '.initialize' do
    context 'when key does not exist' do
      it 'returns an instance of described_class with unmapped' do
        expect(subject).to be_an_instance_of(described_class)
      end
    end

    context 'when key exists' do
      let(:key) { 'unmapped_service_exception' }

      it 'returns an instance of described_class with the key' do
        expect(subject).to be_an_instance_of(described_class)
      end
    end
  end
end
