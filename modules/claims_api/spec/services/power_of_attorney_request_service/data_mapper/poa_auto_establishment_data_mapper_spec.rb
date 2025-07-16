# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../poa_auto_establishment_spec_helper'

describe ClaimsApi::PowerOfAttorneyRequestService::DataMapper::PoaAutoEstablishmentDataMapper do
  let(:clazz) { described_class }

  let(:individual_subject) { build_subject('2122a') }
  let(:organization_subject) { build_subject('2122') }

  include_context 'shared POA auto establishment data'

  context 'determines which form we need to build' do
    it 'when type is 2122' do
      expect_any_instance_of(
        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::OrganizationDataMapper
      ).to receive(:map_data)

      organization_subject.map_data
    end
<<<<<<< HEAD
=======

    it 'when type is 2122a' do
      expect_any_instance_of(
        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::IndividualDataMapper
      ).to receive(:map_data)

      individual_subject.map_data
    end
>>>>>>> 1255e92ce7 (WIP)
  end

  context 'maps and validates the form data' do
    it 'validates the form data using the custom validations' do
      allow_any_instance_of(
        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::OrganizationDataMapper
      ).to receive(:map_data).and_return(valid_form)

      expect_any_instance_of(clazz).to receive(:validate_form_2122_and_2122a_submission_values)
<<<<<<< HEAD
      expect_any_instance_of(clazz).to receive(:validate_json_schema)
=======
>>>>>>> 1255e92ce7 (WIP)

      organization_subject.map_data
    end
  end

  private

  def build_subject(type)
    described_class.new(
      type:,
      data:,
      veteran:
    )
  end
end
