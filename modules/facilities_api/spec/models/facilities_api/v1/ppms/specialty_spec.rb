# frozen_string_literal: true

require 'rails_helper'

describe FacilitiesApi::V1::PPMS::Specialty, type: :model, team: :facilities do
  it 'defaults to nil' do
    specialty = FacilitiesApi::V1::PPMS::Specialty.new
    expect(specialty.attributes).to match(
      {
        classification: nil,
        grouping: nil,
        name: nil,
        specialization: nil,
        specialty_code: nil,
        specialty_description: nil
      }
    )
  end

  it 'transforms :coded_specialty into :specialty_code' do
    specialty = FacilitiesApi::V1::PPMS::Specialty.new(coded_specialty: 'SomeCode')
    expect(specialty.attributes[:specialty_code]).to eql('SomeCode')
  end
end
