# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::DischargeType do
  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) { attributes_for :discharge_type }
    let(:other) { build :discharge_type }

    it 'populates attributes' do
      name_map = described_class.attribute_set.map(&:name)

      expect(name_map).to contain_exactly(:id, :description)
      expect(subject.id).to eq(params[:id])
      expect(subject.description).to eq(params[:description])
    end

    it 'can be compared by description' do
      expect(subject <=> other).to eq(-1)
      expect(other <=> subject).to eq(1)
    end
  end
end
