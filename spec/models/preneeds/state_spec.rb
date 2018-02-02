# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::State do
  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) { attributes_for :preneeds_state }
    let(:other) { described_class.new(attributes_for(:preneeds_state)) }

    it 'populates attributes' do
      name_map = described_class.attribute_set.map(&:name)

      expect(name_map).to contain_exactly(:code, :first_five_zip, :last_five_zip, :lower_indicator, :name)
      expect(subject.code).to eq(params[:code])
      expect(subject.first_five_zip).to eq(params[:first_five_zip])
      expect(subject.last_five_zip).to eq(params[:last_five_zip])
      expect(subject.last_five_zip).to eq(params[:last_five_zip])
      expect(subject.name).to eq(params[:name])
    end

    it 'can be compared by name' do
      expect(subject <=> other).to eq(-1)
      expect(other <=> subject).to eq(1)
    end
  end
end
