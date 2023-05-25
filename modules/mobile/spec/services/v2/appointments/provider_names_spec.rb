# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V2::Appointments::ProviderNames do
  let(:user) { FactoryBot.build(:iam_user) }
  let(:subject) { described_class.new(user) }
  let(:single_practitioner_with_name) do
    [
      {
        "identifier": [
          {
            "system": 'dfn-983',
            "value": '520647669'
          }
        ],
        "name": {
          "family": 'KNIEFEL',
          "given": [
            'CAROLYN'
          ]
        }
      }
    ]
  end
  let(:multiple_practioners_with_names) do
    single_practitioner_with_name + [{
      "identifier": [
        {
          "system": 'dfn-983',
          "value": '520647363'
        }
      ],
      "name": {
        "family": 'NADEAU',
        "given": [
          'MARCY'
        ]
      }
    }]
  end
  let(:practitioner_without_name) do
    [
      {
        "identifier": [
          {
            "system": 'dfn-983',
            "value": '1407938061'
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
      expect(subject.form_names_from_appointment_practitioners_list(nil)).to be_nil
    end

    it 'returns nil when provided an empty array' do
      expect(subject.form_names_from_appointment_practitioners_list([])).to be_nil
    end

    it 'returns nil when provided an input that is not an array or nil' do
      expect(subject.form_names_from_appointment_practitioners_list({})).to be_nil
    end

    it 'returns names as first_name last_name' do
      name = subject.form_names_from_appointment_practitioners_list(single_practitioner_with_name)
      expect(name).to eq('CAROLYN KNIEFEL')
    end

    it 'handles partial names predictably' do
      partial_name_data = single_practitioner_with_name.first
      partial_name_data[:name].delete(:given)
      name = subject.form_names_from_appointment_practitioners_list([partial_name_data])
      expect(name).to eq('KNIEFEL')
    end

    it 'aggregates multiple names as a comma separated list' do
      name = subject.form_names_from_appointment_practitioners_list(multiple_practioners_with_names)
      expect(name).to eq('CAROLYN KNIEFEL, MARCY NADEAU')
    end

    it 'forms names from upstream when an identifier is found without a name' do
      allow_any_instance_of(VAOS::V2::MobilePPMSService).to\
        receive(:get_provider).with('1407938061').and_return(provider_response)
      name = subject.form_names_from_appointment_practitioners_list(practitioner_without_name)
      expect(name).to eq('DEHGHAN, AMIR')
    end

    it 'can request multiple upstream providers' do
      multiple_practitioners_without_names = practitioner_without_name + [{
        "identifier": [
          {
            "system": 'dfn-983',
            "value": '1407938062'
          }
        ]
      }]
      second_provider_response = OpenStruct.new({ 'providerIdentifier' => '1407938062', 'name' => 'J. Jones' })

      allow_any_instance_of(VAOS::V2::MobilePPMSService).to\
        receive(:get_provider).with('1407938061').and_return(provider_response)
      allow_any_instance_of(VAOS::V2::MobilePPMSService).to\
        receive(:get_provider).with('1407938062').and_return(second_provider_response)
      name = subject.form_names_from_appointment_practitioners_list(multiple_practitioners_without_names)
      expect(name).to eq('DEHGHAN, AMIR, J. Jones')
    end

    it 'only requests an upstream provider once' do
      expect_any_instance_of(VAOS::V2::MobilePPMSService).to\
        receive(:get_provider).with('1407938061').once.and_return(provider_response)
      subject.form_names_from_appointment_practitioners_list(practitioner_without_name)
      subject.form_names_from_appointment_practitioners_list(practitioner_without_name)
    end

    it 'returns nil when the ppms service raises an error' do
      allow_any_instance_of(VAOS::V2::MobilePPMSService).to\
        receive(:get_provider).and_raise(Common::Exceptions::BackendServiceException)
      name = subject.form_names_from_appointment_practitioners_list(practitioner_without_name)
      expect(name).to be_nil
    end

    it 'returns nil if the returned provider does not match the expected structure' do
      nameless_provider = OpenStruct.new
      allow_any_instance_of(VAOS::V2::MobilePPMSService).to\
        receive(:get_provider).with('1407938061').and_return(nameless_provider)

      name = subject.form_names_from_appointment_practitioners_list(practitioner_without_name)
      expect(name).to be_nil
    end
  end
end
