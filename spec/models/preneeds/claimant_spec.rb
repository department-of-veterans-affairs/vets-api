# frozen_string_literal: true
require 'rails_helper'
require 'support/preneeds_helpers'

RSpec.describe Preneeds::Claimant do
  include Preneeds::Helpers

  subject { described_class.new(params) }

  let(:params) { attributes_for :claimant }

  it 'populates the model' do
    expect(json_symbolize(subject)).to eq(xml_dates(params))
  end

  it 'specifies the permitted_params' do
    expect(described_class.permitted_params).to include(
      :date_of_birth, :desired_cemetery, :email, :phone_number, :relationship_to_vet, :ssn
    )

    expect(described_class.permitted_params).to include(
      address: Preneeds::Address.permitted_params, name: Preneeds::Name.permitted_params
    )
  end

  it 'produces a message hash whose keys are ordered' do
    expect(subject.message.keys).to eq(
      [
        :address, :dateOfBirth, :desiredCemetery, :email, :name, :phoneNumber, :relationshipToVet, :ssn
      ]
    )
  end
end
