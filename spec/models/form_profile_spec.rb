# frozen_string_literal: true
require 'rails_helper'
require 'support/attr_encrypted_matcher'

RSpec.describe FormProfile, type: :model do
  let(:user) { build(:loa3_user) }
  let(:expected) do
    {
      'veteranFullName' => {
        'first' => 'Abraham',
        'middle' => nil,
        'last' => 'Lincoln',
        'suffix' => nil
      },
      'veteranDateOfBirth' => '1809-02-12',
      'veteranAddress' => {
        'street' => '140 Rock Creek Church Road NW',
        'street_2' => nil,
        'city' => 'Washington',
        'state' => 'DC',
        'country' => 'USA',
        'postal_code' => '20011'
      },
      'gender' => 'M',
      'homePhone' => '2028290436'
    }
  end

  after(:each) do
    subject.class.instance_variable_set(:@mappings, nil)
  end

  describe '#prefill_form' do
    context 'with a healthcare application form' do
      it 'returns the va profile mapped to the healthcare form' do
        expect(JSON.load(subject.prefill_form('healthcare_application', user).to_json)).to eq(expected)
      end
    end

    context 'with an education benefits form' do
      it 'returns va profile mapped to the education benefits form' do
        expect(JSON.load(subject.prefill_form('edu_benefits', user).to_json)).to eq(expected)
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
        expect(YAML).to receive(:load_file).once.and_return('foo' => %w(bar bar))
        instance1.prefill_form('healthcare_application', user)
        instance2.prefill_form('healthcare_application', user)
      end
    end
  end
end
