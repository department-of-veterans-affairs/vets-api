# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/adapters/immunization_adapter'
require 'unified_health_data/models/immunization'

RSpec.describe 'ImmunizationAdapter' do
  let(:adapter) { UnifiedHealthData::Adapters::ImmunizationAdapter.new }
  let(:vaccine_sample_response) do
    JSON.parse(Rails.root.join(
      'spec', 'fixtures', 'unified_health_data', 'immunizations_sample.json'
    ).read)
  end

  before do
    allow(UnifiedHealthData::Immunization).to receive(:new).and_call_original
  end

  describe '#parse_single_immunization' do
    it 'returns the expected fields for happy path for vista immunization with all fields' do
      vista_single_record = vaccine_sample_response['vista']['entry'][0]
      # This also checks fallbacks and nil guards since VistA data is missing many fields
      parsed_immunization = adapter.parse_single_immunization(vista_single_record)

      expect(parsed_immunization).to have_attributes(
        {
          'id' => '431b45a9-9070-4f8c-8de5-ab9cf9403fce',
          'cvx_code' => 90_732,
          'date' => '2024-11-26T20:35:00Z',
          'dose_number' => 'SERIES 1',
          'dose_series' => nil,
          'group_name' => 'PNEUMOCOCCAL POLYSACCHARIDE PPV23',
          'location' => 'NUCLEAR MED',
          'manufacturer' => nil,
          'note' => nil,
          'reaction' => nil,
          'short_description' => 'PNEUMOCOCCAL POLYSACCHARIDE PPV23',
          'administration_site' => 'LEFT DELTOID',
          'lot_number' => nil,
          'status' => 'completed'
        }
      )
    end

    it 'returns the expected fields for happy path for OH immunization with all fields' do
      parsed_immunization = adapter.parse_single_immunization(vaccine_sample_response['oracle-health']['entry'][0])

      expect(parsed_immunization).to have_attributes(
        {
          'id' => 'M20875183434',
          'cvx_code' => 140,
          'date' => '2025-12-10T16:20:00-06:00',
          'dose_number' => 'Unknown',
          'dose_series' => nil,
          'group_name' => 'influenza virus vaccine, inactivated',
          'location' => '556 Captain James A Lovell IL VA Medical Center',
          'manufacturer' => 'Seqirus USA Inc',
          'note' => 'Added comment "note"',
          'reaction' => nil,
          'short_description' => 'influenza virus vaccine, inactivated',
          'administration_site' => 'Shoulder, left (deltoid)',
          'lot_number' => 'AX5586C',
          'status' => 'completed'
        }
      )
    end
  end

  describe '#extract_cvx_code' do
    it 'returns the cvx code if present' do
      vaccine_code = {
        'coding' => [
          {
            'system' => 'https://fhir.cerner.com/d45741b3-8335-463d-ab16-8c5f0bcf78ed/codeSet/72',
            'code' => '2820755',
            'display' => 'influenza virus vaccine, inactivated',
            'userSelected' => true
          },
          {
            'system' => 'http://hl7.org/fhir/sid/cvx',
            'code' => '140',
            'display' => 'influenza vaccine (Afluria) [3 yr+] 2025-2026 PF Prefilled Syringe IM suspension',
            'userSelected' => false
          },
          {
            'system' => 'http://hl7.org/fhir/sid/ndc',
            'code' => '33332-0025-03',
            'display' => 'Afluria PF Prefilled Syringe 2025-2026',
            'userSelected' => true
          }
        ],
        'text' => 'influenza virus vaccine, inactivated'
      }
      expect(adapter.send(:extract_cvx_code, vaccine_code)).to eq('140'.to_i)
    end

    it 'returns the first code if no system' do
      vaccine_code = {
        'coding' => [
          { 'code' => '91322', 'display' => 'SARSCOV2 VAC 50 MCG/0.5ML IM' }
        ],
        'text' => 'COVID-19 (MODERNA), MRNA, LNP-S, PF, 50 MCG/0.5 ML (AGES 12+ YEARS)'
      }
      expect(adapter.send(:extract_cvx_code, vaccine_code)).to eq('91322'.to_i)
    end
  end

  describe '#extract_group_name' do
    let(:vaccine_code_default) do
      { 'vaccineCode' => {
          'coding' => [
            {
              'system' => 'https://fhir.cerner.com/d45741b3-8335-463d-ab16-8c5f0bcf78ed/codeSet/72',
              'code' => '4145920',
              'display' => 'HPV',
              'userSelected' => true
            },
            {
              'system' => 'http://hl7.org/fhir/sid/cvx',
              'code' => '165',
              'display' => 'human papillomavirus vaccine 9-valent intramuscular suspension',
              'userSelected' => false
            },
            {
              'system' => 'http://hl7.org/fhir/sid/ndc',
              'code' => '00006-4121-02',
              'display' => 'Gardasil 9',
              'userSelected' => true
            }
          ],
          'text' => 'human papillomavirus vaccine'
        },
        'protocolApplied' => [
          {
            'targetDisease' => [
              {
                'coding' => [
                  {
                    'display' => 'poliovirus vaccine, unspecified formulation'
                  }
                ],
                'text' => 'Polio'
              }
            ],
            'doseNumberString' => '1'
          }
        ] }
    end

    before do
      allow(PersonalInformationLog).to receive(:create!)
    end

    it 'returns the vaccineCode.text for name if present' do
      expect(PersonalInformationLog).to receive(:create!)
        .with({
                error_class: 'UHD Vaccine Group Names',
                data: {
                  vaccine_code_text: 'human papillomavirus vaccine',
                  vaccine_codes_display: ['HPV',
                                          'human papillomavirus vaccine 9-valent intramuscular suspension',
                                          'Gardasil 9'],
                  target_disease_text: 'Polio',
                  service: 'unified_health_data'
                }
              })
      expect(adapter.send(:extract_group_name, vaccine_code_default)).to eq('human papillomavirus vaccine')
    end

    it 'returns the cvx display if no text' do
      vaccine_code = vaccine_code_default.dup
      vaccine_code['vaccineCode'].delete('text')
      expect(adapter.send(:extract_group_name,
                          vaccine_code))
        .to eq('human papillomavirus vaccine 9-valent intramuscular suspension')
    end

    it 'returns the cerner system display if no text or cvx code' do
      vaccine_code = { 'vaccineCode' => {
        'coding' => [
          {
            'system' => 'https://fhir.cerner.com/d45741b3-8335-463d-ab16-8c5f0bcf78ed/codeSet/72',
            'code' => '4145920',
            'display' => 'HPV',
            'userSelected' => true
          },
          {
            'system' => 'http://hl7.org/fhir/sid/ndc',
            'code' => '00006-4121-02',
            'display' => 'Gardasil 9',
            'userSelected' => true
          }
        ]
      } }
      expect(adapter.send(:extract_group_name,
                          vaccine_code)).to eq('HPV')
    end

    it 'returns the ndc display if no text, cvx code, or cerner options' do
      vaccine_code = { 'vaccineCode' => {
        'coding' => [
          {
            'system' => 'http://hl7.org/fhir/sid/ndc',
            'code' => '00006-4121-02',
            'display' => 'Gardasil 9',
            'userSelected' => true
          }
        ]
      } }
      expect(adapter.send(:extract_group_name,
                          vaccine_code)).to eq('Gardasil 9')
    end

    it 'returns the first display if no text, and system data does not match' do
      vaccine_code = { 'vaccineCode' => {
        'coding' => [
          {
            'code' => '4145920',
            'display' => 'Vaccine name',
            'userSelected' => true
          },
          {
            'system' => 'http://random.system.org/code',
            'code' => '00006-4121-02',
            'display' => 'Gardasil 9',
            'userSelected' => true
          }
        ]
      } }

      expect(adapter.send(:extract_group_name,
                          vaccine_code)).to eq('Vaccine name')
    end
  end

  describe '#extract_manufacturer' do
    it 'returns the manufacturer name if present' do
      resource = {
        'id' => 'M20875183430',
        'manufacturer' => { 'display' => 'Merck & Company Inc' }
      }
      expect(adapter.send(:extract_manufacturer, resource)).to eq('Merck & Company Inc')
    end

    it 'returns nil if not found' do
      resource = {
        'id' => 'M20875183430'
      }
      expect(adapter.send(:extract_manufacturer, resource)).to be_nil
    end
  end

  describe '#extract_note' do
    it 'returns the note text if present' do
      resource = {
        'id' => 'M20875183430',
        'note' => [
          { 'text' => 'Patient is allergic to eggs.' }
        ]
      }
      expect(adapter.send(:extract_note, resource['note'])).to eq('Patient is allergic to eggs.')
    end

    it 'concats the note array into single string if multiple items present' do
      resource = {
        'id' => 'M20875183430',
        'note' => [
          { 'text' => 'Patient is allergic to eggs.' },
          { 'text' => 'Patient is also allergic to peanuts.' }
        ]
      }
      expect(adapter.send(:extract_note,
                          resource['note'])).to eq('Patient is allergic to eggs., Patient is also allergic to peanuts.')
    end

    it 'returns nil if no notes' do
      resource = {
        'id' => 'M20875183430',
        'note' => []
      }
      expect(adapter.send(:extract_note, resource['note'])).to be_nil
    end
  end

  describe '#extract_location_display' do
    it 'returns the location display from the performer array if present' do
      resource = {
        'id' => 'M20875183430',
        'performer' => [
          {
            'function' => {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/v2-0443',
                  'code' => 'AP',
                  'display' => 'Administering Provider'
                }
              ],
              'text' => 'Administering Provider'
            },
            'actor' => {
              'reference' => 'Practitioner/63662034',
              'display' => 'Borland, Victoria A'
            }
          },
          {
            'function' => {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/v2-0443',
                  'code' => 'OP',
                  'display' => 'Ordering Provider'
                }
              ],
              'text' => 'Ordering Provider'
            },
            'actor' => {
              'reference' => 'Practitioner/63662034',
              'display' => 'Borland, Victoria A'
            }
          },
          {
            'actor' => {
              'reference' => 'Organization/2044131',
              'display' => '556 Captain James A Lovell IL VA Medical Center'
            }
          }
        ],
        'location' => {
          'reference' => 'GREELEY NURSE',
          'display' => 'GREELEY NURSE'
        }
      }

      expect(adapter.send(:extract_location_display, resource)).to eq('556 Captain James A Lovell IL VA Medical Center')
    end

    it 'returns the location display from the location if organization performer not present' do
      resource = {
        'id' => 'M20875183430',
        'performer' => [
          {
            'function' => {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/v2-0443',
                  'code' => 'AP',
                  'display' => 'Administering Provider'
                }
              ],
              'text' => 'Administering Provider'
            },
            'actor' => {
              'reference' => 'Practitioner/63662034',
              'display' => 'Borland, Victoria A'
            }
          },
          {
            'function' => {
              'coding' => [
                {
                  'system' => 'http://terminology.hl7.org/CodeSystem/v2-0443',
                  'code' => 'OP',
                  'display' => 'Ordering Provider'
                }
              ],
              'text' => 'Ordering Provider'
            },
            'actor' => {
              'reference' => 'Practitioner/63662034',
              'display' => 'Borland, Victoria A'
            }
          }
        ],
        'location' => {
          'reference' => 'GREELEY NURSE',
          'display' => 'GREELEY NURSE'
        }
      }

      expect(adapter.send(:extract_location_display, resource)).to eq('GREELEY NURSE')
    end

    it 'returns nil if no location information present' do
      resource = {
        'id' => 'M20875183430',
        'location' => {}
      }
      expect(adapter.send(:extract_location_display, resource)).to be_nil
    end
  end

  describe '#extract_site' do
    it 'returns the site text if present' do
      resource = {
        'id' => 'M20875183430',
        'site' => {
          'coding' => [
            {
              'display' => 'Shoulder, left (deltoid)'
            },
            {
              'display' => 'Structure of left deltoid muscle (body structure)'
            }
          ],
          'text' => 'Left shoulder'
        }
      }
      expect(adapter.send(:extract_site, resource)).to eq('Left shoulder')
    end

    it 'returns the first display if multiple items present' do
      resource = {
        'id' => 'M20875183430',
        'site' => { 'coding' => [
          {
            'display' => 'Shoulder, left (deltoid)'
          },
          {
            'display' => 'Structure of left deltoid muscle (body structure)'
          }
        ] }
      }
      expect(adapter.send(:extract_site,
                          resource)).to eq('Shoulder, left (deltoid)')
    end

    it 'returns nil if no site data present' do
      resource = {
        'id' => 'M20875183430'
      }
      expect(adapter.send(:extract_site, resource)).to be_nil
    end
  end
end
