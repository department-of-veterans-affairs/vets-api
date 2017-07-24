# frozen_string_literal: true
require 'rails_helper'
require 'support/preneeds_helpers'

RSpec.describe Preneeds::Address do
  include Preneeds::Helpers

  subject { described_class.new(params) }

  let(:params) { attributes_for :address }

  it 'populates the model' do
    expect(json_symbolize(subject)).to eq(params)
  end

  it 'specifies the permitted_params' do
    expect(described_class.permitted_params).to include(
      :address1, :address2, :address3, :city, :country_code, :postal_zip, :state
    )
  end

  it 'produces a message hash whose keys are ordered' do
    expect(subject.message.keys).to eq([:address1, :address2, :address3, :city, :countryCode, :postalZip, :state])
  end
end
