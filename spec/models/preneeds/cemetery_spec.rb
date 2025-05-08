# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::Cemetery do
  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) { attributes_for(:cemetery) }
    let(:other) { described_class.new(attributes_for(:cemetery)) }

    it 'populates attributes' do
      expect(described_class.attribute_set).to contain_exactly(:name, :num, :cemetery_type)
      expect(subject.name).to eq(params[:name])
      expect(subject.num).to eq(params[:num])
      expect(subject.cemetery_type).to eq(params[:cemetery_type])
    end

    it 'can be compared by name' do
      expect(subject <=> other).to eq(-1)
      expect(other <=> subject).to eq(1)
    end
  end
end
