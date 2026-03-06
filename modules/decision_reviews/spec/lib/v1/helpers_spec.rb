# frozen_string_literal: true

require 'rails_helper'
require 'decision_reviews/v1/helpers'

describe DecisionReviews::V1::Helpers do
  let(:helper) { Class.new { include DecisionReviews::V1::Helpers }.new }

  describe 'format_phone_number' do
    context 'international phone numbers' do
      it 'returns {} if phone is nil' do
        expect(helper.format_phone_number(nil)).to eq({})
      end

      it 'formats phone number with country code, area code, and number' do
        phone = { 'countryCode' => '44', 'areaCode' => '20', 'phoneNumber' => '5550456' }
        expect(helper.format_phone_number(phone)).to eq({
                                                          internationalPhoneNumber: '+44 205550456'
                                                        })
      end

      it 'formats phone number with nil area code' do
        phone = { 'areaCode' => nil, 'countryCode' => '44', 'phoneNumber' => '5550456' }
        expect(helper.format_phone_number(phone)).to eq({
                                                          internationalPhoneNumber: '+44 5550456'
                                                        })
      end

      it 'formats phone number with empty area code' do
        phone = { 'areaCode' => '', 'countryCode' => '44', 'phoneNumber' => '5550456' }
        expect(helper.format_phone_number(phone)).to eq({
                                                          internationalPhoneNumber: '+44 5550456'
                                                        })
      end

      it 'formats phone number with no area code' do
        phone = { 'countryCode' => '44', 'phoneNumber' => '5550456' }
        expect(helper.format_phone_number(phone)).to eq({
                                                          internationalPhoneNumber: '+44 5550456'
                                                        })
      end
    end

    context 'domestic phone numbers' do
      it 'formats phone number with nil country code' do
        phone = { 'countryCode' => nil, 'areaCode' => '210', 'phoneNumber' => '5550456' }
        expect(helper.format_phone_number(phone)).to eq({
                                                          veteranPhone: '2105550456'
                                                        })
      end

      it 'formats phone number with empty country code' do
        phone = { 'countryCode' => '', 'areaCode' => '210', 'phoneNumber' => '5550456' }
        expect(helper.format_phone_number(phone)).to eq({
                                                          veteranPhone: '2105550456'
                                                        })
      end

      it 'formats phone number with no country code' do
        phone = { 'areaCode' => '210', 'phoneNumber' => '5550456' }
        expect(helper.format_phone_number(phone)).to eq({
                                                          veteranPhone: '2105550456'
                                                        })
      end
    end
  end

  describe '#normalize_area_code_for_lighthouse_schema' do
    context 'when area_code is present and valid with 3 characters (domestic number)' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'areaCode' => '123',
                  'phoneNumber' => '1234567',
                  'countryCode' => '1'
                }
              }
            }
          }
        }
      end

      it 'returns the original object unchanged' do
        expected_result = req_body_obj
        expect(helper.normalize_area_code_for_lighthouse_schema(req_body_obj)).to eq(expected_result)
      end
    end

    context 'when area_code is present and valid with 2 characters (international number)' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'areaCode' => '10',
                  'phoneNumber' => '49808232',
                  'countryCode' => '100'
                }
              }
            }
          }
        }
      end

      it 'returns the original object unchanged' do
        expected_result = req_body_obj
        expect(helper.normalize_area_code_for_lighthouse_schema(req_body_obj)).to eq(expected_result)
      end
    end

    context 'when area_code is present and empty' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'areaCode' => '',
                  'phoneNumber' => '12343432567',
                  'countryCode' => '44'
                }
              }
            }
          }
        }
      end

      let(:expected_result) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'phoneNumber' => '12343432567',
                  'countryCode' => '44'
                }
              }
            }
          }
        }
      end

      it 'returns the object without an areaCode' do
        expect(helper.normalize_area_code_for_lighthouse_schema(req_body_obj)).to eq(expected_result)
      end
    end

    context 'when area_code is present and nil' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'areaCode' => nil,
                  'phoneNumber' => '12343432567',
                  'countryCode' => '44'
                }
              }
            }
          }
        }
      end

      let(:expected_result) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'phoneNumber' => '12343432567',
                  'countryCode' => '44'
                }
              }
            }
          }
        }
      end

      it 'returns the object without an areaCode' do
        expect(helper.normalize_area_code_for_lighthouse_schema(req_body_obj)).to eq(expected_result)
      end
    end
  end

  describe '#format_va_evidence_entries' do
    let(:va_evidence) do
      [
        {
          'treatmentMonthYear' => '2000-02',
          'treatmentBefore2005' => 'Y',
          'issuesVA' => {
            'Hypertension' => true,
            'Impotence' => true,
            'Let Knee Instability' => true
          },
          'vaTreatmentLocation' => 'Midwest Alabama VA Facility'
        },
        {
          'treatmentBefore2005' => 'N',
          'issuesVA' => {
            'Let Knee Instability' => true,
            'Right Knee Injury' => true
          },
          'vaTreatmentLocation' => 'Edith Nourse Rogers Memorial'
        }
      ]
    end

    let(:expected_result) do
      [
        {
          'type' => 'retrievalEvidence',
          'attributes' => {
            'locationAndName' => 'Midwest Alabama VA Facility',
            'evidenceDates' => [{
              'startDate' => '2000-02-01',
              'endDate' => '2000-02-01'
            }],
            'noTreatmentDates' => false
          }
        },
        {
          'type' => 'retrievalEvidence',
          'attributes' => {
            'locationAndName' => 'Edith Nourse Rogers Memorial',
            'noTreatmentDates' => true
          }
        }
      ]
    end

    it 'formats VA evidence entries correctly' do
      expect(helper.format_va_evidence_entries(va_evidence)).to eq(expected_result)
    end
  end

  describe '#format_private_evidence_entries' do
    context 'with limited consent information' do
      let(:private_evidence) do
        {
          'auth4142' => true,
          'lcDetails' => 'I only want my records from Dr. Smith',
          'lcPrompt' => 'Y',
          'evidenceEntries' => [
            {
              'treatmentStart' => '2020-02-20',
              'treatmentEnd' => '2020-02-21',
              'issuesPrivate' => {
                'Impotence' => true,
                'Left Knee Instability' => true,
                'Hypertension' => false
              },
              'privateTreatmentLocation' => 'South Texas VA Facility',
              'address' => {
                'view:militaryBaseDescription' => {},
                'country' => 'USA',
                'street' => '123 Main Street',
                'street2' => 'Address line 2',
                'city' => 'San Antonio',
                'state' => 'TX',
                'postalCode' => '78258'
              }

            },
            {
              'treatmentStart' => '2007-08-09',
              'treatmentEnd' => '2007-09-10',
              'issuesPrivate' => {
                'Right Knee Injury' => true
              },
              'privateTreatmentLocation' => 'Oakglen Memorial',
              'address' => {
                'view:militaryBaseDescription' => {},
                'country' => 'USA',
                'street' => '764 Oakland Ave',
                'city' => 'San Diego',
                'state' => 'CA',
                'postalCode' => '89047'
              }
            }
          ]
        }
      end

      let(:expected_result) do
        {
          'privacyAgreementAccepted' => true,
          'limitedConsent' => 'I only want my records from Dr. Smith',
          'providerFacility' => [
            {
              'providerFacilityName' => 'South Texas VA Facility',
              'providerFacilityAddress' => {
                'country' => 'USA',
                'street' => '123 Main Street',
                'street2' => 'Address line 2',
                'city' => 'San Antonio',
                'state' => 'TX',
                'postalCode' => '78258'
              },
              'issues' => ['Impotence', 'Left Knee Instability'],
              'treatmentDateRange' => [{
                'from' => '2020-02-20',
                'to' => '2020-02-21'
              }]
            },
            {
              'providerFacilityName' => 'Oakglen Memorial',
              'providerFacilityAddress' => {
                'country' => 'USA',
                'street' => '764 Oakland Ave',
                'street2' => '',
                'city' => 'San Diego',
                'state' => 'CA',
                'postalCode' => '89047'
              },
              'issues' => ['Right Knee Injury'],
              'treatmentDateRange' => [{
                'from' => '2007-08-09',
                'to' => '2007-09-10'
              }]
            }
          ]
        }
      end

      it 'formats private evidence entries correctly' do
        expect(helper.format_private_evidence_entries(private_evidence)).to eq(expected_result)
      end
    end

    context 'with no limited consent information' do
      let(:private_evidence) do
        {
          'auth4142' => true,
          'lcPrompt' => 'N',
          'evidenceEntries' => [
            {
              'treatmentStart' => '1997-08-15',
              'treatmentEnd' => '2001-11-10',
              'issuesPrivate' => {
                'Migraines' => true
              },
              'privateTreatmentLocation' => 'Central Mississippi VA Clinic',
              'address' => {
                'view:militaryBaseDescription' => {},
                'country' => 'USA',
                'street' => '900 W. Pine Street',
                'city' => 'Jackson',
                'state' => 'MS',
                'postalCode' => '46763'
              },
              'auth4142' => true,
              'lcPrompt' => 'N'
            }
          ]
        }
      end

      let(:expected_result) do
        {
          'privacyAgreementAccepted' => true,
          'providerFacility' => [
            {
              'providerFacilityName' => 'Central Mississippi VA Clinic',
              'providerFacilityAddress' => {
                'country' => 'USA',
                'street' => '900 W. Pine Street',
                'street2' => '',
                'city' => 'Jackson',
                'state' => 'MS',
                'postalCode' => '46763'
              },
              'issues' => ['Migraines'],
              'treatmentDateRange' => [{
                'from' => '1997-08-15',
                'to' => '2001-11-10'
              }]
            }
          ]
        }
      end

      it 'formats private evidence entries correctly' do
        expect(helper.format_private_evidence_entries(private_evidence)).to eq(expected_result)
      end
    end
  end
end
