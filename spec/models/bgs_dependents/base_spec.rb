# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::Base do
  let(:base) { described_class.new }
  let(:sample_dependent_application) do
    {
      'veteran_contact_information' => {
        'veteran_address' => {
          'country_name' => 'USA',
          'address_line1' => '8200 Doby LN',
          'city' => 'Pasadena',
          'state_code' => 'CA',
          'zip_code' => '21122'
        }
      }
    }
  end
  let(:alternative_address) do
    {
      'country_name' => 'USA',
      'address_line1' => 'Alternative LN',
      'city' => 'Stuart',
      'state_code' => 'FL',
      'zip_code' => '21122'
    }
  end

  describe '#dependent_address' do
    it 'returns the vet\'s address' do
      address = base.dependent_address(
        dependents_application: sample_dependent_application,
        lives_with_vet: true,
        alt_address: nil
      )

      expect(address).to eq(sample_dependent_application['veteran_contact_information']['veteran_address'])
    end

    it 'returns the alternative address' do
      address = base.dependent_address(
        dependents_application: sample_dependent_application,
        lives_with_vet: false,
        alt_address: alternative_address
      )

      expect(address).to eq(alternative_address)
    end
  end
end
