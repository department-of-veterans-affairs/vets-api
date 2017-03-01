# frozen_string_literal: true
require 'rails_helper'
require 'support/attr_encrypted_matcher'

RSpec.describe FormProfile, type: :model do
  let(:user) { build(:loa3_user) }
  let(:expected) do
    {
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'middle' => nil,
        'last' => user.last_name&.capitalize,
        'suffix' => nil
      },
      'veteranDateOfBirth' => user.birth_date,
      'veteranAddress' => {
        'street' => user.va_profile[:address][:street_address_line],
        'street_2' => nil,
        'city' => user.va_profile[:address][:city],
        'state' => user.va_profile[:address][:state],
        'country' => user.va_profile[:address][:country],
        'postal_code' => user.va_profile[:address][:postal_code]
      },
      'gender' => user.gender,
      'homePhone' => user.va_profile[:home_phone]
    }
  end

  before(:each) do
    subject.class.instance_variable_set(:@mappings, nil)
  end

  describe '#prefill_form' do
    context 'with a healthcare application form' do
      it 'returns the va profile mapped to the healthcare form' do
        expect(Oj.load(subject.prefill_form('healthcare_application', user).to_json)).to eq(expected)
      end
    end

    context 'with an education benefits form' do
      it 'returns va profile mapped to the education benefits form' do
        expect(Oj.load(subject.prefill_form('edu_benefits', user).to_json)).to eq(expected)
      end
    end

    context 'when the form mapping can not be found' do
      it 'raises an IOError' do
        expect { subject.prefill_form('foo', user) }.to raise_error(IOError)
      end
    end
  end

  describe '.mappings_for_form' do
    context 'with multiple form profile instances' do
      let(:instance1) { FormProfile.new }
      let(:instance2) { FormProfile.new }

      it 'loads the yaml file only once' do
        expect(YAML).to receive(:load_file).once.and_return(
          'veteran_full_name' => ['identity_information', 'full_name'],
          'gender' => ['identity_information', 'gender'],
          'veteran_date_of_birth' => ['identity_information', 'date_of_birth'],
          'veteran_address' => ['contact_information', 'address'],
          'home_phone' => ['contact_information', 'home_phone']
        )
        instance1.prefill_form('healthcare_application', user)
        instance2.prefill_form('healthcare_application', user)
      end
    end
  end
end
