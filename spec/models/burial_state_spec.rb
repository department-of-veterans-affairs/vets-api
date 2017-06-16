# frozen_string_literal: true
require 'rails_helper'

RSpec.describe BurialState do
  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) do
      { code: 'AA', first_five_zip: '11111', last_five_zip: '22222', lower_indicator: 'Y', name: 'AA' }
    end

    let(:other) do
      described_class.new(code: 'BB', first_five_zip: '33333', last_five_zip: '44444', lower_indicator: 'Y', name: 'BB')
    end

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
