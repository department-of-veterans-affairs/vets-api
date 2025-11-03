# frozen_string_literal: true

require 'burials/pdf_fill/sections/section_05'

describe Burials::PdfFill::Section5 do
  describe '#expand_location_of_death' do
    context 'with a location of death of home hospice care after discharge' do
      let(:form_data) do
        {
          'locationOfDeath' => {
            'location' => 'atHome'
          },
          'homeHospiceCare' => true,
          'homeHospiceCareAfterDischarge' => true
        }
      end

      it 'returns the directly mapped location' do
        described_class.new.expand_location_of_death(form_data)
        expect(form_data['locationOfDeath']['checkbox']).to eq({ 'nursingHomePaid' => 'On' })
      end
    end

    context 'with a location of death of home hospice care (not after discharge)' do
      let(:form_data) do
        {
          'locationOfDeath' => {
            'location' => 'atHome'
          },
          'homeHospiceCare' => true,
          'homeHospiceCareAfterDischarge' => false
        }
      end

      it 'returns the directly mapped location' do
        described_class.new.expand_location_of_death(form_data)
        expect(form_data['locationOfDeath']['checkbox']).to eq({ 'nursingHomeUnpaid' => 'On' })
      end
    end

    context 'with a regular location of death in new format' do
      let(:form_data) do
        {
          'locationOfDeath' => {
            'location' => 'nursingHomeUnpaid'
          },
          'nursingHomeUnpaid' => {
            'facilityName' => 'facility name',
            'facilityLocation' => 'Washington, DC'
          }
        }
      end

      it 'returns the directly mapped location' do
        described_class.new.expand_location_of_death(form_data)
        expect(form_data['locationOfDeath']['checkbox']).to eq({ 'nursingHomeUnpaid' => 'On' })
        expect(form_data['locationOfDeath']['placeAndLocation']).to eq('facility name - Washington, DC')
      end
    end

    context 'with a location needed for translation' do
      let(:form_data) do
        {
          'locationOfDeath' => {
            'location' => 'atHome'
          },
          'homeHospiceCare' => false,
          'homeHospiceCareAfterDischarge' => false
        }
      end

      it 'returns the directly mapped location' do
        described_class.new.expand_location_of_death(form_data)
        expect(form_data['locationOfDeath']['checkbox']).to eq({ 'nursingHomeUnpaid' => 'On' })
      end
    end
  end
end
