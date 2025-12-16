# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v2/poa_pdf_constructor/organization'
require_relative '../../../../support/pdf_matcher'

describe ClaimsApi::V2::PoaPdfConstructor::Organization do
  subject { ClaimsApi::V2::PoaPdfConstructor::Organization.new }

  let(:power_of_attorney) { create(:power_of_attorney, :with_full_headers) }
  # we do not do anything for item 3 & 6
  let(:item_one) { %w[GRAY JESSE] } # veteran name
  let(:item_two) { %w[796 37 8881] } # vet ssn
  let(:item_four) { %w[12 05 1953] } # vet birthdate
  let(:item_five) { nil } # insurance number
  let(:item_seven) { [nil, nil, nil, nil, nil, nil, nil] } # vet address
  let(:item_eight) { nil } # telephone
  let(:item_nine) { nil } # email
  let(:item_ten) { [nil, nil] } # claimant's name
  let(:item_eleven) { [nil, nil, nil, nil, nil, nil, nil] } # claimant's address
  let(:item_twelve) { nil } # claimant's telephone
  let(:item_thirteen) { nil } # claimant's email
  let(:item_fourteen) { nil } # claimant's relationship to vet
  let(:item_fifteen) { 'I Help Vets LLC' } # name of service org
  let(:item_sixteen_a) { 'Bob Representative' } # rep name
  let(:item_sixteen_b) { nil } # job title (for item 15)
  let(:item_seventeen) { nil } # org email
  let(:item_eighteen) { '01/01/2020' } # appointment date
  let(:expected_page1_values) do
    [
      *item_one, *item_two, *item_four, item_five, *item_seven,
      item_eight, item_nine, *item_ten, *item_eleven, item_twelve,
      item_thirteen, item_fourteen, item_fifteen, item_sixteen_a,
      item_sixteen_b, item_seventeen, item_eighteen
    ]
  end
  let(:expected_page2_values) do
    [
      *item_two, # build for vet ssn
      0, # record consent
      0, 0, 0, 0, 0, # consent limits
      '01/01/2020', # date signed
      '01/01/2020' # date signed
    ]
  end
  let(:data) do
    power_of_attorney.form_data.deep_merge(
      {
        'veteran' => veteran_attributes,
        'appointmentDate' => power_of_attorney.created_at,
        'text_signatures' => signatures,
        'serviceOrganization' => service_org
      }
    )
  end
  let(:signatures) do
    {
      'page2' => [
        {
          'signature' => 'Lillian Disney - signed via api.va.gov',
          'x' => 35,
          'y' => 240
        },
        {
          'signature' => 'Bob Representative - signed via api.va.gov',
          'x' => 35,
          'y' => 200
        }
      ]
    }
  end
  let(:veteran_attributes) do
    {
      'firstName' => power_of_attorney.auth_headers['va_eauth_firstName'],
      'lastName' => power_of_attorney.auth_headers['va_eauth_lastName'],
      'ssn' => power_of_attorney.auth_headers['va_eauth_pnid'],
      'birthdate' => power_of_attorney.auth_headers['va_eauth_birthdate']
    }
  end
  let(:dependent_attributes) do
    {
      'dependent' => {
        'first_name' => 'Lillian',
        'last_name' => 'Disney'
      }
    }
  end
  let(:service_org) do
    {
      'firstName' => 'Bob',
      'lastName' => 'Representative',
      'organizationName' => 'I Help Vets LLC'
    }
  end

  before do
    Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
  end

  after do
    Timecop.return
  end

  context 'page1_options' do
    it 'returns the expected values' do
      res = subject.send(:page1_options, data)

      expect(res.values).to match(expected_page1_values)
    end

    it 'returns the expected values with a dependent' do
      data_w_claimant = data.deep_merge!(dependent_attributes)

      res = subject.send(:page1_options, data_w_claimant)

      expect(res.values).to include('Lillian', 'Disney')
    end
  end

  describe '#page2_options pdf' do
    it 'returns the expected values' do
      res = subject.send(:page2_options, data)

      expect(res.values).to eq(expected_page2_values)
    end
  end
end
