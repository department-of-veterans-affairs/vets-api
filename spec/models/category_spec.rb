# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Category do
  subject { described_class.new(params) }

  let(:params) { attributes_for(:category) }

  it 'populates attributes' do
    expect(subject.message_category_type).to eq(params[:message_category_type])
  end

  it 'can be compared but always equal' do
    expect(subject <=> build(:category)).to eq(0)
  end
end
