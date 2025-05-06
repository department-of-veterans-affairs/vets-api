# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::Veteran do
  subject { described_class.new(params) }

  let(:params) { attributes_for(:veteran) }

  it 'specifies the permitted_params' do
    expect(described_class.permitted_params).to include(
      :date_of_birth, :date_of_death, :gender, :is_deceased, :marital_status,
      :military_service_number, :place_of_birth, :ssn, :va_claim_number, :military_status
    )

    expect(described_class.permitted_params).to include(
      race: Preneeds::Race.permitted_params,
      address: Preneeds::Address.permitted_params, current_name: Preneeds::FullName.permitted_params,
      service_name: Preneeds::FullName.permitted_params, service_records: [Preneeds::ServiceRecord.permitted_params]
    )
  end

  describe 'when converting to eoas' do
    it 'produces a message hash whose keys are ordered' do
      expect(subject.as_eoas.keys).to eq(
        %i[
          address currentName dateOfBirth dateOfDeath gender race
          isDeceased maritalStatus militaryServiceNumber placeOfBirth
          serviceName serviceRecords ssn vaClaimNumber militaryStatus
        ]
      )
    end

    it 'removes :dateOfBirth, dateOfDeath and :placeOfBirth if blank' do
      params[:date_of_birth] = ''
      params[:date_of_death] = ''
      params[:place_of_birth] = ''

      expect(subject.as_eoas.keys).not_to include(:dateOfBirth, :dateOfDeath, :placeOfBirth)
    end
  end

  describe 'when converting to json' do
    it 'converts its attributes from snakecase to camelcase' do
      camelcased = params.deep_transform_keys { |key| key.to_s.camelize(:lower) }
      expect(camelcased).to eq(subject.as_json)
    end
  end
end
