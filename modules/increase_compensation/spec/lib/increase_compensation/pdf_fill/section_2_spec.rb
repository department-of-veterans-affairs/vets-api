# frozen_string_literal: true

require 'rails_helper'

describe IncreaseCompensation::PdfFill::Section2 do
  describe 'doctorsCareInLastYTD boolean field' do
    it 'get mapped correctly' do
      s2 = described_class.new
      data = { 'doctorsCareInLastYTD' => true }
      s2.expand(data)
      expect(data['doctorsCareInLastYTD']).to eq('YES')
      data['doctorsCareInLastYTD'] = false
      s2.expand(data)
      expect(data['doctorsCareInLastYTD']).to eq('NO')
      data['doctorsCareInLastYTD'] = ''
      s2.expand(data)
      expect(data['doctorsCareInLastYTD']).to eq('OFF')
    end
  end

  describe 'overflow triggers' do
    it 'overflows when the doctor list is greater than 1' do
      s2 = described_class.new
      data = {
        'doctorsCare' => [
          {
            'inVANetwork' => true,
            'doctorsTreatmentDates' => [
              { 'from' => '2024-01-10',
                'to' => '2025-02-20' }
            ],
            'nameAndAddressOfDoctor' => 'Dr. Hubert Farnsworth, 456 Medical St, Cheyenne, WY 82001',
            'relatedDisability' => ['PTSD']
          },
          {
            'inVANetwork' => true,
            'doctorsTreatmentDates' => [
              { 'from' => '2024-01-10',
                'to' => '2025-02-20' }
            ],
            'nameAndAddressOfDoctor' => 'Dr. Zoidberg, 456 Medical St, Cheyenne, WY 82001',
            'relatedDisability' => ['PTSD']
          }
        ]
      }

      s2.expand(data)
      expect(data['doctorsCareOverflow']).to eq(
        ["VA - Dr. Hubert Farnsworth, 456 Medical St, Cheyenne, WY 82001\nTreated for: PTSD\nFrom: 2024-01-10, To: 2025-02-20\n\n\nVA - Dr. Zoidberg, 456 Medical St, Cheyenne, WY 82001\nTreated for: PTSD\nFrom: 2024-01-10, To: 2025-02-20\n"] # rubocop:disable Layout/LineLength
      )
      expect(data['nameAndAddressesOfDoctors']).to eq('See Additional Pages')
    end

    it 'overflows when the hospital list is greater than 1' do
      s2 = described_class.new
      data = {
        'hospitalsCare' => [
          {
            'inVANetwork' => false,
            'nameAndAddressOfHospital' => 'Cheyenne VA Medical Center, 789 Health Ave, Cheyenne, WY 82001',
            'hospitalTreatmentDates' => [
              {
                'from' => '2024-06-01',
                'to' => '2024-06-15'
              }
            ],
            'relatedDisability' => ['shrapnel wounds']
          },
          {
            'inVANetwork' => false,
            'nameAndAddressOfHospital' => 'Cheyenne VA Medical Center, 789 Health Ave, Cheyenne, WY 82001',
            'hospitalTreatmentDates' => [
              {
                'from' => '2024-06-01',
                'to' => '2024-06-15'
              }
            ],
            'relatedDisability' => ['shrapnel wounds']
          }
        ]
      }

      s2.expand(data)
      expect(data['hospitalCareOverflow']).to eq(
        ["Non-VA - Cheyenne VA Medical Center, 789 Health Ave, Cheyenne, WY 82001\nTreated for: shrapnel wounds\nFrom: 2024-06-01, To: 2024-06-15\n\n\nNon-VA - Cheyenne VA Medical Center, 789 Health Ave, Cheyenne, WY 82001\nTreated for: shrapnel wounds\nFrom: 2024-06-01, To: 2024-06-15\n"] # rubocop:disable Layout/LineLength
      )
      expect(data['nameAndAddressesOfHospitals']).to eq('See Additional Pages')
    end
  end
end
