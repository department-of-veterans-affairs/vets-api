# frozen_string_literal: true
require 'rails_helper'
require 'support/preneeds_helpers'

RSpec.describe Preneeds::Applicant do
  include Preneeds::Helpers

  subject { described_class.new(params) }

  let(:params) { attributes_for :applicant }

  it 'populates the model' do
    expect(json_symbolize(subject)).to eq(params)
  end

  it 'specifies the permitted_params' do
    expect(described_class.permitted_params).to include(
      :applicant_email, :applicant_phone_number, :applicant_relationship_to_claimant, :completing_reason
    )

    expect(described_class.permitted_params).to include(
      mailing_address: Preneeds::Address.permitted_params, name: Preneeds::Name.permitted_params
    )
  end

  it 'produces a message hash whose keys are ordered' do
    expect(subject.message.keys).to eq(
      [
        :applicantEmail, :applicantPhoneNumber, :applicantRelationshipToClaimant,
        :completingReason, :mailingAddress, :name
      ]
    )
  end
end
