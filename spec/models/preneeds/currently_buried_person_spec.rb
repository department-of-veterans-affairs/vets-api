# frozen_string_literal: true
require 'rails_helper'
require 'support/preneeds_helpers'

RSpec.describe Preneeds::CurrentlyBuriedPerson do
  include Preneeds::Helpers

  subject { described_class.new(params) }

  let(:params) { attributes_for :currently_buried_person }

  it 'populates the model' do
    expect(json_symbolize(subject)).to eq(params)
  end

  it 'specifies the permitted_params' do
    expect(described_class.permitted_params).to include(:cemetery_number)
    expect(described_class.permitted_params).to include(name: Preneeds::Name.permitted_params)
  end

  it 'produces a message hash whose keys are ordered' do
    expect(subject.message.keys).to eq([:cemetery_number, :name])
  end
end
