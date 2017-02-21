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

  describe '#prefill_form' do
    context 'with a healthcare application form' do
      it 'returns the va profile' do
        expect(Mvi).to receive(:find).once
        expect(JSON.load(subject.prefill_form('healthcare_application', user).to_json)).to eq(expected)
      end
    end

    context 'with an education benefits form' do
      it 'returns the stored profile rather than the va profile' do
        expect(Mvi).to_not receive(:find).once
        expect(JSON.load(subject.prefill_form('edu_benefits', user).to_json)).to eq(expected)
      end
    end

    context 'when the form mapping can not be found' do
      it 'raises an IOError' do
        expect { subject.prefill_form('foo', user) }.to raise_error(IOError)
      end
    end
  end
end
