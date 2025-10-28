# frozen_string_literal: true

require 'pensions/pdf_fill/sections/section_08'

describe Pensions::PdfFill::Section8 do
  describe '#expand_dependent_children' do
    it 'handles partially removed dependents' do
      form_data = {
        'dependents' => [
          {
            'childAddress' => {
              'country' => 'US',
              'city' => 'Cityville',
              'street' => '100 Main St',
              'state' => 'PA',
              'postalCode' => '11111'
            },
            'personWhoLivesWithChild' => {
              'last' => 'John',
              'first' => 'Smith'
            },
            'monthlyPayment' => 1200
          }
        ]
      }

      described_class.new.expand(form_data)

      expect(form_data['dependents'].length).to eq(1)
      expect(form_data['custodians'].length).to eq(1)
      expect(form_data['dependentChildrenInHousehold']).to eq('0')
      expect(form_data['dependentsNotWithYouAtSameAddress']).to eq(0)
    end

    it 'handles overflow for dependent children not in the same household' do
      form_data = {
        'dependents' => [
          {
            'childAddress' => {
              'country' => 'US',
              'city' => 'Cityville',
              'street' => '100 Main St',
              'state' => 'PA',
              'postalCode' => '11111'
            },
            'childInHousehold' => false,
            'fullName' => {
              'first' => 'John',
              'middle' => 'A',
              'last' => 'Smith'
            },
            'personWhoLivesWithChild' => {
              'first' => 'Jane',
              'last' => 'Doe'
            },
            'monthlyPayment' => 500
          },
          {
            'childAddress' => {
              'country' => 'US',
              'city' => 'Cityville',
              'street' => '100 Main St',
              'state' => 'PA',
              'postalCode' => '11111'
            },
            'childInHousehold' => false,
            'fullName' => {
              'first' => 'Alice',
              'middle' => 'B',
              'last' => 'Johnson'
            },
            'personWhoLivesWithChild' => {
              'first' => 'Jane',
              'last' => 'Doe'
            },
            'monthlyPayment' => 700
          }
        ]
      }

      described_class.new.expand(form_data)

      expect(form_data['custodians'][0]['dependentsWithCustodianOverflow']).to eq('John A Smith, Alice B Johnson')
    end
  end
end
