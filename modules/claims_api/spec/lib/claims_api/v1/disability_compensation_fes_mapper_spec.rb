# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v1/disability_compensation_fes_mapper'

describe ClaimsApi::V1::DisabilityCompensationFesMapper do
  describe '#map_claim' do
    subject(:mapped) { described_class.new(auto_claim).map_claim }

    let(:fixture_attrs) do
      JSON.parse(
        Rails.root.join(
          'modules',
          'claims_api',
          'spec',
          'fixtures',
          'form_526_json_api.json'
        ).read
      )['data']['attributes']
    end

    let(:form_attrs) { fixture_attrs.deep_dup }

    let(:auto_claim) do
      create(
        :auto_established_claim,
        form_data: form_attrs,
        auth_headers: { 'va_eauth_pid' => '600061742' }
      )
    end

    describe 'request structure' do
      it 'includes form526 and veteran' do
        expect(mapped).to have_key(:data)
        expect(mapped[:data]).to have_key(:form526)
        expect(mapped[:data][:form526]).to have_key(:veteran)
      end
    end

    describe 'veteran information' do
      let(:veteran) { mapped[:data][:form526][:veteran] }

      describe 'current mailing address' do
        context 'when address is domestic' do
          it 'maps as DOMESTIC with full fields' do
            addr = veteran[:currentMailingAddress]
            expect(addr[:addressLine1]).to eq('1234 Couch Street')
            expect(addr[:addressLine2]).to eq('Apt. 22')
            expect(addr[:addressLine3]).to be_nil
            expect(addr[:city]).to eq('Portland')
            expect(addr[:state]).to eq('OR')
            expect(addr[:country]).to eq('USA')
            expect(addr[:zipFirstFive]).to eq('12345')
            expect(addr[:zipLastFour]).to eq('6789')
            expect(addr[:addressType]).to eq('DOMESTIC')
          end
        end

        context 'when address is military (APO/FPO/DPO)' do
          let(:form_attrs) do
            attrs = fixture_attrs.deep_dup
            attrs['veteranIdentification'] = {
              'currentVaEmployee' => false,
              'mailingAddress' => {
                'numberAndStreet' => 'CMR 468 Box 1181',
                'city' => 'APO',
                'state' => 'AE',
                'country' => 'USA',
                'zipFirstFive' => '09277'
              }
            }
            attrs
          end

          it 'maps as MILITARY and omits city/state' do
            addr = veteran[:currentMailingAddress]
            expect(addr[:addressLine1]).to eq('CMR 468 Box 1181')
            expect(addr[:militaryPostOfficeTypeCode]).to eq('APO')
            expect(addr[:militaryStateCode]).to eq('AE')
            expect(addr[:addressType]).to eq('MILITARY')
            expect(addr).not_to have_key(:city)
            expect(addr).not_to have_key(:state)
          end
        end

        context 'when address is international' do
          let(:form_attrs) do
            attrs = fixture_attrs.deep_dup
            attrs['veteranIdentification'] = {
              'currentVaEmployee' => false,
              'mailingAddress' => {
                'numberAndStreet' => '123 Main St',
                'city' => 'London',
                'country' => 'GBR',
                'internationalPostalCode' => 'SW1A 1AA'
              }
            }
            attrs
          end

          it 'maps as INTERNATIONAL with postal code' do
            addr = veteran[:currentMailingAddress]
            expect(addr[:addressLine1]).to eq('123 Main St')
            expect(addr[:internationalPostalCode]).to eq('SW1A 1AA')
            expect(addr[:addressType]).to eq('INTERNATIONAL')
            expect(addr[:country]).to eq('GBR')
          end
        end
      end

      describe 'change of address' do
        context 'when present' do
          let(:form_attrs) do
            attrs = fixture_attrs.deep_dup
            attrs['changeOfAddress'] = {
              'typeOfAddressChange' => 'TEMPORARY',
              'numberAndStreet' => '10 Peach St',
              'apartmentOrUnitNumber' => 'Unit 4',
              'city' => 'Schenectady',
              'state' => 'NY',
              'country' => 'USA',
              'zipFirstFive' => '12345',
              'beginningDate' => '2023-06-04',
              'endingDate' => '2023-12-04'
            }
            attrs
          end

          it 'maps fields and dates correctly' do
            change = veteran[:changeOfAddress]
            expect(change[:addressChangeType]).to eq('TEMPORARY')
            expect(change[:addressLine1]).to eq('10 Peach St Unit 4')
            expect(change[:beginningDate]).to eq('2023-06-04')
            expect(change[:endingDate]).to eq('2023-12-04')
            expect(change[:addressType]).to eq('DOMESTIC')
          end
        end
      end
    end
  end
end
