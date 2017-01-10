# frozen_string_literal: true
require 'rails_helper'
require 'evss/mhvcf/client'

describe EVSS::MHVCF::MHVConsentFormRequestForm do
  let(:full_name) { Faker::Name.name }
  let(:ssn) { Faker::Number.number(9) }
  let(:ssn_masked) { '*' * 5 + ssn.chars.last(4).join }
  let(:dob) { 60.years.ago.strftime('%d/%m/%Y') }
  let(:date_sign) { Time.current.strftime('%d/%m/%Y') }
  let(:phone) { Faker::PhoneNumber.phone_number }

  let(:valid_attrs) do
    {
      patient_full_name: full_name,
      ssn: ssn,
      ssn_masked: ssn_masked,
      dob: dob,
      patient_phone_number: phone,
      date_sign: date_sign
    }
  end

  subject { described_class.new(valid_attrs) }

  it 'valid? returns true if attributes are valid' do
    expect(subject.valid?).to be_truthy
  end

  # Add additional failing specs for validations

  context 'params' do
    it 'contains form_data' do
      expect(subject.params.keys).to contain_exactly(:form_data)
    end

    it 'form_data has additional keys' do
      expect(subject.params[:form_data].keys)
        .to contain_exactly(:common_headers, :form_config_id, :form_field_data, :over_flow_form_field_data)
    end

    it 'form_data has a configuraiton node' do
      expect(subject.params[:form_data][:form_config_id])
        .to eq(config_version: '1.0.0', form_type: '10-5345A-MHV')
    end

    it 'form_data has data fields' do
      data_fields = subject.params[:form_data][:form_field_data]
      expect(data_fields).to be_an(Array)
      data = data_fields.inject({}) { |a, e| a.merge(e[:name].snakecase.to_sym => e[:values].first) }
      expect(data).to eq(valid_attrs)
    end
  end
end
