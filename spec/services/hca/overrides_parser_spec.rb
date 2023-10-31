# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HCA::OverridesParser do
  describe '#override' do
    context 'with Mexico as the country' do
      let(:address_json) do
        {
          veteranHomeAddress: {
            street: '123 NW 5th St',
            street2: '',
            street3: '',
            city: 'Ontario',
            country: 'MEX',
            state: 'aguascalientes',
            provinceCode: 'ProvinceName',
            postalCode: '21231'
          },
          veteranAddress: {
            street: '123 NW 5th St',
            street2: '',
            street3: '',
            city: 'Ontario',
            country: 'MEX',
            state: 'aguascalientes',
            provinceCode: 'ProvinceName',
            postalCode: '21231'
          },
          spouseAddress: {
            street: '123 NW 8th St',
            street2: '',
            street3: '',
            city: 'Dulles',
            country: 'MEX',
            state: 'Test',
            postalCode: '20101-0101'
          }
        }.as_json
      end

      it 'returns a proper state abbreviation' do
        parser = described_class.new(address_json)
        parsed_form = parser.override.as_json

        expect(parsed_form['veteranHomeAddress']['state']).to eq('AGS.')
        expect(parsed_form['veteranAddress']['state']).to eq('AGS.')
        expect(parsed_form['spouseAddress']['state']).to eq('Test')
      end
    end

    context 'without overriden data' do
      let(:address_json) do
        {
          veteranAddress: {
            street: '123 NW 5th St',
            street2: '',
            street3: '',
            city: 'Ontario',
            country: 'USA',
            state: 'VA',
            provinceCode: 'ProvinceName',
            postalCode: '21231'
          }
        }.as_json
      end

      it 'returns a proper state abbreviation' do
        parser = described_class.new(address_json)
        parsed_form = parser.override

        expect(parsed_form['veteranAddress']['state']).to eq('VA')
      end
    end
  end
end
