# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v2/poa_pdf_constructor/individual'
require_relative '../../../../support/pdf_matcher'

describe ClaimsApi::V2::PoaPdfConstructor::Individual do
  subject { ClaimsApi::V2::PoaPdfConstructor::Individual.new }

  let(:power_of_attorney) { create(:power_of_attorney, :with_full_headers) }
  let(:signatures) do
    { 'page2' => [
      { 'signature' => 'Lillian Disney - signed via api.va.gov', 'x' => 35, 'y' => 306 },
      { 'signature' => 'Bob Law - signed via api.va.gov', 'x' => 35, 'y' => 200 }
    ] }
  end
  let(:rep_attributes) do
    {
      'firstName' => 'Bob',
      'lastName' => 'Law'
    }
  end
  let(:dependent_attributes) do
    {
      'first_name' => 'Lillian',
      'last_name' => 'Disney'
    }
  end
  let(:date_signed) { '01/01/2020' }
  # we do not do anything for item 3
  let(:item_one) { %w[GRAY JESSE] } # veteran name
  let(:item_two) { %w[796 37 8881] } # vet ssn
  let(:item_four) { %w[12 05 1953] } # vet birthdate
  let(:item_five) { '987654321' } # insurance number
  let(:item_six) { [1, 0, 0, 0, 0, 0, 0, nil] } # service branch:
  let(:item_seven) { ['2719 Hyperion Ave', nil, 'Los Angeles', 'CA', 'US', '92264', nil] } # vet address
  let(:item_eight) { '+1 555 5551337' } # telephone
  let(:item_nine) { 'test@example.com' } # email
  let(:item_ten) { %w[Lillian Disney] } # claimant's name
  let(:item_eleven) { ['2688 S Camino Real', nil, 'Palm Springs', 'CA', 'US', '92264', nil] } # claimant's address
  let(:item_twelve) { '+44 555 5551337' } # claimant's telephone
  let(:item_thirteen) { 'lillian@disney.com' } # claimant's email
  let(:item_fourteen) { 'Spouse' } # claimant's relationship to vet
  let(:item_fifteen_a) { 'Bob Law' } # representative name
  let(:item_fifteen_b) { [1, 0] } # representative type: ATTORNEY or AGENT
  let(:item_eighteen) { '2719 Hyperion Ave, Los Angeles CA 92264' } # address of rep
  let(:item_nineteen) { 1 } # record consent
  let(:item_twenty) { %(DRUG ABUSE, SICKLE CELL) } # consent limits
  let(:item_twenty_one) { 1 } # consentAddressChange
  # 22b and 24b are date signed
  let(:item_twenty_three) { %(Condition 1, Condition 2) } # conditionsOfAppointment
  let(:expected_page1_values) do
    [
      *item_one, *item_two, *item_four, item_five, *item_six, *item_seven,
      item_eight, item_nine, *item_ten, *item_eleven, item_twelve,
      item_thirteen, item_fourteen, item_fifteen_a, *item_fifteen_b,
      item_eighteen
    ]
  end
  let(:expected_page2_values) do
    [
      *item_two, item_nineteen, *item_twenty, item_twenty_one, date_signed,
      *item_twenty_three, date_signed
    ]
  end

  before do
    Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
    power_of_attorney.form_data = {
      veteran: {
        serviceNumber: '987654321',
        serviceBranch: 'ARMY',
        address: {
          addressLine1: '2719 Hyperion Ave',
          city: 'Los Angeles',
          stateCode: 'CA',
          country: 'US',
          zipCode: '92264'
        },
        phone: {
          countryCode: '1',
          areaCode: '555',
          phoneNumber: '5551337'
        },
        email: 'test@example.com'
      },
      claimant: {
        claimantId: '00000000V0000',
        email: 'lillian@disney.com',
        relationship: 'Spouse',
        address: {
          addressLine1: '2688 S Camino Real',
          city: 'Palm Springs',
          stateCode: 'CA',
          country: 'US',
          zipCode: '92264'
        },
        phone: {
          countryCode: '44',
          areaCode: '555',
          phoneNumber: '5551337'
        }
      },
      representative: {
        poaCode: 'A1Q',
        registrationNumber: '1234',
        type: 'ATTORNEY',
        address: {
          addressLine1: '2719 Hyperion Ave',
          city: 'Los Angeles',
          stateCode: 'CA',
          country: 'US',
          zipCode: '92264'
        }
      },
      recordConsent: true,
      consentAddressChange: true,
      consentLimits: %w[DRUG_ABUSE SICKLE_CELL],
      conditionsOfAppointment: ['Condition 1', 'Condition 2']
    }
    power_of_attorney.form_data.deep_merge!(
      {
        'veteran' => veteran_attributes(power_of_attorney.auth_headers),
        'representative' => rep_attributes,
        'dependent' => dependent_attributes,
        'appointmentDate' => power_of_attorney.created_at,
        'text_signatures' => signatures
      }
    )
    power_of_attorney.save!
  end

  after do
    Timecop.return
  end

  context 'page1_options' do
    it 'returns the expected values' do
      res = subject.send(:page1_options, power_of_attorney.form_data)

      expect(res.values).to match(expected_page1_values)
    end
  end

  context 'page2_options' do
    it 'returns the expected values' do
      res = subject.send(:page2_options, power_of_attorney.form_data)

      expect(res.values).to match(expected_page2_values)
    end
  end

  private

  def veteran_attributes(auth_headers)
    {
      'firstName' => auth_headers['va_eauth_firstName'],
      'lastName' => auth_headers['va_eauth_lastName'],
      'ssn' => auth_headers['va_eauth_pnid'],
      'birthdate' => auth_headers['va_eauth_birthdate']
    }
  end

  def data_for_poa(poa)
    {
      'veteran' => veteran(poa.auth_headers),
      'appointmentDate' => poa.created_at,
      'text_signatures' => signatures,
      'representative' => representative
    }
  end
end
