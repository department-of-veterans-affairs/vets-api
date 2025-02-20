# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::Applicant do
  subject { described_class.new(params) }

  let(:params) { attributes_for(:applicant) }

  it 'specifies the permitted_params' do
    expect(described_class.permitted_params).to include(
      :applicant_email, :applicant_phone_number, :applicant_relationship_to_claimant, :completing_reason
    )

    expect(described_class.permitted_params).to include(
      mailing_address: Preneeds::Address.permitted_params, name: Preneeds::FullName.permitted_params
    )
  end

  describe 'when converting to eoas' do
    it 'produces an ordered hash' do
      expect(subject.as_eoas.keys).to eq(
        %i[
          applicantEmail applicantPhoneNumber applicantRelationshipToClaimant
          completingReason mailingAddress name
        ]
      )
    end
  end

  describe 'when converting to json' do
    it 'converts its attributes from snakecase to camelcase' do
      camelcased = params.deep_transform_keys { |key| key.to_s.camelize(:lower) }
      expect(camelcased).to eq(subject.as_json)
    end
  end
end
