# frozen_string_literal: true
require 'rails_helper'
require 'support/preneeds_helpers'

RSpec.describe Preneeds::Veteran do
  include Preneeds::Helpers

  subject { described_class.new(params) }

  let(:params) { attributes_for :veteran }

  it 'populates the model' do
    expect(json_symbolize(subject)).to eq(xml_dates(params))
  end

  it 'specifies the permitted_params' do
    expect(described_class.permitted_params).to include(
      :date_of_birth, :date_of_death, :gender, :is_deceased, :marital_status,
      :military_service_number, :place_of_birth, :ssn, :va_claim_number
    )

    expect(described_class.permitted_params).to include(
      address: Preneeds::Address.permitted_params, current_name: Preneeds::Name.permitted_params,
      service_name: Preneeds::Name.permitted_params, service_records: [Preneeds::ServiceRecord.permitted_params],
      military_status: []
    )
  end

  it 'produces a message hash whose keys are ordered' do
    expect(subject.message.keys).to eq(
      [
        :address, :currentName, :dateOfBirth, :dateOfDeath, :gender,
        :isDeceased, :maritalStatus, :militaryServiceNumber, :placeOfBirth,
        :serviceName, :serviceRecords, :ssn, :vaClaimNumber, :militaryStatus
      ]
    )
  end
end
