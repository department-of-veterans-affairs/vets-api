# frozen_string_literal: true
require 'rails_helper'
require 'support/preneeds_helpers'

RSpec.describe Preneeds::Name do
  include Preneeds::Helpers

  subject { described_class.new(params) }

  let(:params) { attributes_for :name }

  it 'populates the model' do
    expect(json_symbolize(subject)).to eq(params)
  end

  it 'specifies the permitted_params' do
    expect(described_class.permitted_params).to include(
      :first_name, :last_name, :maiden_name, :middle_name, :suffix
    )
  end

  it 'produces a message hash whose keys are ordered' do
    expect(subject.message.keys).to eq([:firstName, :lastName, :maidenName, :middleName, :suffix])
  end
end
