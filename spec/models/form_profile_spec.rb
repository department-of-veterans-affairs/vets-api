# frozen_string_literal: true
require 'rails_helper'
require 'support/attr_encrypted_matcher'

RSpec.describe FormProfile, type: :model do
  let(:user) { build(:loa3_user) }
  let(:v1010ez_expected) do
    {
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.va_profile[:suffix]
      },
      'veteranDateOfBirth' => user.birth_date,
      'email' => user.email,
      'veteranAddress' => {
        'street' => user.va_profile[:address][:street],
        'city' => user.va_profile[:address][:city],
        'state' => user.va_profile[:address][:state],
        'country' => user.va_profile[:address][:country],
        'postal_code' => user.va_profile[:address][:postal_code]
      },
      'gender' => user.gender,
      'homePhone' => user.va_profile[:home_phone],
      'veteranSocialSecurityNumber' => user.ssn
    }
  end

  let(:v21p527_expected) do
    {
      'veteranFullName' => {
        'first' => user.first_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.va_profile[:suffix]
      },
      'veteranAddress' => {
        'street' => user.va_profile[:address][:street],
        'city' => user.va_profile[:address][:city],
        'state' => user.va_profile[:address][:state],
        'country' => user.va_profile[:address][:country],
        'postal_code' => user.va_profile[:address][:postal_code]
      },
      'gender' => user.gender,
      'dayPhone' => user.va_profile[:home_phone],
      'veteranSocialSecurityNumber' => user.ssn,
      'veteranDateOfBirth' => user.birth_date
    }
  end

  let(:v21p530_expected) do
    {
      'claimantFullName' => {
        'first' => user.first_name&.capitalize,
        'last' => user.last_name&.capitalize,
        'suffix' => user.va_profile[:suffix]
      },
      'claimantAddress' => {
        'street' => user.va_profile[:address][:street],
        'city' => user.va_profile[:address][:city],
        'state' => user.va_profile[:address][:state],
        'country' => user.va_profile[:address][:country],
        'postal_code' => user.va_profile[:address][:postal_code]
      },
      'claimantPhone' => user.va_profile[:home_phone],
      'claimantEmail' => user.email
    }
  end

  before(:each) do
    described_class.instance_variable_set(:@mappings, nil)
  end

  describe '#prefill_form' do
    context 'with a healthcare application form' do
      it 'returns the va profile mapped to the healthcare form' do
        expect(Oj.load(described_class.for('1010ez').prefill(user).to_json)['form_data']).to eq(v1010ez_expected)
      end
    end

    context 'with a burial application form' do
      it 'returns the va profile mapped to the burial form' do
        expect(Oj.load(described_class.for('21P-530').prefill(user).to_json)['form_data']).to eq(v21p530_expected)
      end
    end

    context 'with a pension application form' do
      it 'returns the va profile mapped to the pension form' do
        expect(Oj.load(described_class.for('21P-527EZ').prefill(user).to_json)['form_data']).to eq(v21p527_expected)
      end
    end

    context 'when the form mapping can not be found' do
      it 'raises an IOError' do
        expect { described_class.new('foo').prefill(user) }.to raise_error(IOError)
      end
    end
  end

  describe '.mappings_for_form' do
    context 'with multiple form profile instances' do
      let(:instance1) { FormProfile.new('1010ez') }
      let(:instance2) { FormProfile.new('1010ez') }

      it 'loads the yaml file only once' do
        expect(YAML).to receive(:load_file).once.and_return(
          'veteran_full_name' => %w(identity_information full_name),
          'gender' => %w(identity_information gender),
          'veteran_date_of_birth' => %w(identity_information date_of_birth),
          'veteran_address' => %w(contact_information address),
          'home_phone' => %w(contact_information home_phone)
        )
        instance1.prefill(user)
        instance2.prefill(user)
      end
    end
  end
end
