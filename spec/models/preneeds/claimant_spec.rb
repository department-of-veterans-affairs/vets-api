# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::Claimant do
  subject { described_class.new(params) }

  let(:params) { attributes_for(:claimant) }

  it 'specifies the permitted_params' do
    expect(described_class.permitted_params).to include(
      :date_of_birth, :desired_cemetery, :email, :phone_number, :relationship_to_vet, :ssn
    )

    expect(described_class.permitted_params).to include(
      address: Preneeds::Address.permitted_params, name: Preneeds::FullName.permitted_params
    )
  end

  describe 'when converting to eoas' do
    it 'produces an ordered hash' do
      expect(subject.as_eoas.keys).to eq(
        %i[address dateOfBirth desiredCemetery email name phoneNumber relationshipToVet ssn]
      )
    end

    it 'removes :email and :phone_number if blank' do
      params[:email] = ''
      params[:phone_number] = ''
      expect(subject.as_eoas.keys).not_to include(:email, :phoneNumber)
    end
  end

  describe 'when converting to json' do
    it 'converts its attributes from snakecase to camelcase' do
      camelcased = params.deep_transform_keys { |key| key.to_s.camelize(:lower) }
      expect(camelcased).to eq(subject.as_json)
    end
  end
end
