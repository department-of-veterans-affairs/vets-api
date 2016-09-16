# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Category do
  subject { described_class.new(params) }
  let(:params) { attributes_for :category }

  it 'populates attributes' do
    expect(described_class.attribute_set.map(&:name)).to contain_exactly(:names)
    expect(subject.names).to eq(params[:names])
  end

  it 'can be compared but always equal' do
    expect(subject <=> build(:category)).to eq(0)
  end
end
