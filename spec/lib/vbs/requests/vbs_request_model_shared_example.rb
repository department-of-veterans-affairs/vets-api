# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'a VBS request model' do
  it 'inherits from VBS::Requests::Base' do
    expect(described_class.ancestors).to include(VBS::Requests::Base)
  end

  describe '::HTTP_METHOD' do
    it 'is defined' do
      expect(described_class).to have_constant(:HTTP_METHOD)
    end

    it 'is an http verb' do
      expect(%i[get post put patch delete]).to include(described_class::HTTP_METHOD) # rubocop:disable RSpec/ExpectActual
    end
  end

  describe '::PATH' do
    it 'is defined' do
      expect(described_class).to have_constant(:PATH)
    end

    it 'has a leading slash' do
      expect(described_class::PATH[0]).to eq('/')
    end
  end

  describe '::schema' do
    it 'is defined' do
      expect(described_class).to respond_to(:schema)
      expect(described_class.schema).to be_instance_of(Hash)
    end
  end

  describe '#data' do
    it 'returns a hash' do
      expect(subject).to respond_to(:data)
      expect(subject.data).to be_instance_of(Hash)
    end
  end
end
