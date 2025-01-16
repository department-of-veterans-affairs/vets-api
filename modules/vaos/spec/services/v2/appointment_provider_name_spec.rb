# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::AppointmentProviderName do
  let(:user) { build(:user) }
  let(:provider_names) { described_class.new(user) }
  let(:practitioner_list) do
    [
      {
        identifier: [
          {
            system: 'us-npi',
            value: '1407938061'
          }
        ]
      }
    ]
  end
  let(:provider_response) do
    OpenStruct.new({ 'providerIdentifier' => '1407938061', 'name' => 'DEHGHAN, AMIR' })
  end

  describe '#form_names_from_appointment_practitioners_list' do
    it 'returns nil when provided nil' do
      expect(provider_names.form_names_from_appointment_practitioners_list(nil)).to be_nil
    end

    it 'returns nil when provided an empty array' do
      expect(provider_names.form_names_from_appointment_practitioners_list([])).to be_nil
    end

    it 'returns nil when practitioners list contains no provider id' do
      practioner_list_no_value = [
        {
          identifier: [
            {
              system: 'us-npi',
              value: nil
            }
          ]
        }
      ]
      expect(provider_names.form_names_from_appointment_practitioners_list(practioner_list_no_value)).to be_nil
    end

    it 'returns nil is identifier system is not us-npi' do
      practioner_list_wrong_system = [
        {
          identifier: [
            {
              system: 'dfn-983',
              value: '520647669'
            }
          ]
        }
      ]
      expect(provider_names.form_names_from_appointment_practitioners_list(practioner_list_wrong_system)).to be_nil
    end

    it 'uses response from upstream to form a name when provider id present' do
      allow_any_instance_of(VAOS::V2::MobilePPMSService)
        .to receive(:get_provider).with('1407938061').and_return(provider_response)
      name = provider_names.form_names_from_appointment_practitioners_list(practitioner_list)
      expect(name).to eq('DEHGHAN, AMIR')
    end

    it 'uses the name provided from upstream instead of the name provided in practitioners list' do
      practioner_list_with_name = [
        {
          identifier: [
            {
              system: 'us-npi',
              value: '520647669'
            }
          ],
          name: {
            family: 'KNIEFEL',
            given: [
              'CAROLYN'
            ]
          }
        }
      ]
      response = OpenStruct.new({ 'providerIdentifier' => '520647669', 'name' => 'Knieffel, C.' })

      allow_any_instance_of(VAOS::V2::MobilePPMSService)
        .to receive(:get_provider).with('520647669').and_return(response)
      expect(provider_names.form_names_from_appointment_practitioners_list(practioner_list_with_name))
        .to eq(response.name)
    end

    it 'uses the first practitioner when multiple practitioners are in the list' do
      multiple_practitioners_without_names = practitioner_list + [{
        identifier: [
          {
            system: 'us-npi',
            value: '1407938062'
          }
        ]
      }]
      second_provider_response = OpenStruct.new({ 'providerIdentifier' => '1407938062', 'name' => 'J. Jones' })

      allow_any_instance_of(VAOS::V2::MobilePPMSService)
        .to receive(:get_provider).with('1407938061').and_return(provider_response)
      allow_any_instance_of(VAOS::V2::MobilePPMSService)
        .to receive(:get_provider).with('1407938062').and_return(second_provider_response)
      name =
        provider_names.form_names_from_appointment_practitioners_list(multiple_practitioners_without_names)
      expect(name).to eq('DEHGHAN, AMIR')
    end

    it 'only requests an upstream provider once' do
      expect_any_instance_of(VAOS::V2::MobilePPMSService)
        .to receive(:get_provider).with('1407938061').once.and_return(provider_response)
      provider_names.form_names_from_appointment_practitioners_list(practitioner_list)
      provider_names.form_names_from_appointment_practitioners_list(practitioner_list)
    end

    it 'returns not found message when the ppms service raises an error' do
      allow_any_instance_of(VAOS::V2::MobilePPMSService)
        .to receive(:get_provider).and_raise(Common::Exceptions::BackendServiceException)
      name = provider_names.form_names_from_appointment_practitioners_list(practitioner_list)
      expect(name).to eq(VAOS::V2::AppointmentProviderName::NPI_NOT_FOUND_MSG)
    end

    it 'returns nil if the returned provider does not match the expected structure' do
      nameless_provider = OpenStruct.new
      allow_any_instance_of(VAOS::V2::MobilePPMSService)
        .to receive(:get_provider).with('1407938061').and_return(nameless_provider)

      name = provider_names.form_names_from_appointment_practitioners_list(practitioner_list)
      expect(name).to be_nil
    end
  end
end
