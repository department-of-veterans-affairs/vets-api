# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../poa_auto_establishment_spec_helper'
require 'claims_api/v2/error/lighthouse_error_handler'
require 'claims_api/v2/json_format_validation'

describe ClaimsApi::PowerOfAttorneyRequestService::DataMapper::PoaAutoEstablishmentDataMapper do
  let(:clazz) { described_class }

  let(:individual_type) { '2122a' }
  let(:organization_type) { '2122' }
  let(:individual_subject) { build_subject(individual_type, individual_gathered_data) }
  let(:organization_subject) { build_subject(organization_type, org_gathered_data) }

  include_context 'shared POA auto establishment data'

  context 'determines which form we need to build' do
    it 'when type is 2122' do
      allow_any_instance_of(
        ClaimsApi::V2::PowerOfAttorneyValidation
      ).to receive(:validate_claimant_fields).with(anything).and_return(nil)
      expect_any_instance_of(
        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::OrganizationDataMapper
      ).to receive(:map_data).and_return(org_mapped_form_data)

      organization_subject.instance_variable_set(:@data, org_gathered_data)

      organization_subject.map_data
    end

    it 'when type is 2122a' do
      allow_any_instance_of(
        ClaimsApi::V2::PowerOfAttorneyValidation
      ).to receive(:validate_claimant_fields).with(anything).and_return(nil)
      expect_any_instance_of(
        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::IndividualDataMapper
      ).to receive(:map_data).and_return(individual_mapped_form_data)

      individual_subject.instance_variable_set(:@data, individual_gathered_data)

      individual_subject.map_data
    end
  end

  context 'maps and validates the form data' do
    context 'for an organization request' do
      it 'maps the form data' do
        organization_subject.instance_variable_set(:@data, org_gathered_data)

        res = organization_subject.map_data

        expect(res).to eq([org_mapped_form_data, '2122'])
      end
    end

    context 'for an individual request' do
      it 'maps the form data' do
        individual_subject.instance_variable_set(:@data, individual_gathered_data)
        allow_any_instance_of(
          ClaimsApi::PowerOfAttorneyRequestService::DataMapper::IndividualDataMapper
        ).to receive(:representative_type).and_return('ATTORNEY')

        res = individual_subject.map_data

        expect(res).to eq([individual_mapped_form_data, '2122a'])
      end
    end
  end

  context 'returns expected data to the controller' do
    it 'an array with mapped form data and form type' do
      allow_any_instance_of(
        ClaimsApi::PowerOfAttorneyRequestService::DataMapper::IndividualDataMapper
      ).to receive(:representative_type).and_return('ATTORNEY')

      res = individual_subject.map_data

      expect(res).to eq([individual_mapped_form_data, individual_type])
    end
  end

  private

  def build_subject(type, data)
    described_class.new(
      type:,
      data:
    )
  end
end
