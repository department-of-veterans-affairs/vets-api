# frozen_string_literal: true

require 'rails_helper'
require 'form_intake/mappers/base_mapper'
require 'form_intake/mappers/vba_21p_0537_mapper'

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe FormIntake::Mappers::VBA21p0537Mapper do
  let(:form_data) do
    # Form data is snake_cased by middleware before reaching mappers
    {
      'form_number' => '21P-0537',
      'veteran' => {
        'full_name' => { 'first' => 'John', 'middle' => 'M', 'last' => 'Veteran' },
        'ssn' => { 'first3' => '987', 'middle2' => '65', 'last4' => '4321' },
        'va_file_number' => '123456789'
      },
      'recipient' => {
        'full_name' => { 'first' => 'Jane', 'middle' => 'R', 'last' => 'Recipient' },
        'phone' => {
          'daytime' => { 'area_code' => '123', 'prefix' => '456', 'line_number' => '7890' },
          'evening' => { 'area_code' => '321', 'prefix' => '654', 'line_number' => '0987' }
        },
        'email' => 'jane.recipient@email.com',
        'signature' => 'Jane R Recipient',
        'signature_date' => { 'month' => '09', 'day' => '19', 'year' => '2025' }
      },
      'in_reply_refer_to' => '987654321',
      'has_remarried' => true,
      'remarriage' => {
        'date_of_marriage' => { 'month' => '01', 'day' => '20', 'year' => '2020' },
        'spouse_name' => { 'first' => 'Bob', 'middle' => 'T', 'last' => 'Spouse' },
        'spouse_date_of_birth' => { 'month' => '01', 'day' => '17', 'year' => '1978' },
        'spouse_is_veteran' => true,
        'age_at_marriage' => '50',
        'spouse_ssn' => { 'first3' => '555', 'middle2' => '66', 'last4' => '7777' },
        'spouse_va_file_number' => '888888888',
        'has_terminated' => false
      }
    }.to_json
  end

  let(:form_submission) { create(:form_submission, form_type: '21P-0537', form_data:) }
  let(:benefits_intake_uuid) { 'uuid-537-012' }
  let(:mapper) { described_class.new(form_submission, benefits_intake_uuid) }

  describe '#to_gcio_payload' do
    let(:payload) { mapper.to_gcio_payload }

    it 'includes form type with StructuredData prefix' do
      expect(payload['FORM_TYPE']).to eq('StructuredData:21P-0537')
    end

    it 'maps remarriage status checkboxes' do
      expect(payload['REMARRIED_AFTER_VET_DEATH_YES']).to be true
      expect(payload['REMARRIED_AFTER_VET_DEATH_NO']).to be false
    end

    it 'maps date of marriage' do
      expect(payload['DATE_OF_MARRIAGE']).to eq('01/20/2020')
    end

    it 'maps spouse name fields' do
      expect(payload['VETERAN_NAME']).to eq('Bob T Spouse')
      expect(payload['SPOUSE_FIRST_NAME']).to eq('Bob')
      expect(payload['SPOUSE_MIDDLE_INITIAL']).to eq('T')
      expect(payload['SPOUSE_LAST_NAME']).to eq('Spouse')
    end

    it 'maps spouse veteran status checkboxes' do
      expect(payload['SPOUSE_VET_YES']).to be true
      expect(payload['SPOUSE_VET_NO']).to be false
    end

    it 'maps spouse identification' do
      expect(payload['VA_CLAIM_NUMBER']).to eq('888888888')
      expect(payload['SSN']).to eq('555667777')
    end

    it 'maps signature fields' do
      expect(payload['SIGNATURE']).to eq('Jane R Recipient')
      expect(payload['DATE_SIGNED']).to eq('09/19/2025')
    end

    context 'when recipient has not remarried' do
      let(:not_remarried_data) do
        data = JSON.parse(form_data)
        data['has_remarried'] = false
        data.delete('remarriage')
        data.to_json
      end

      let(:form_submission) { create(:form_submission, form_type: '21P-0537', form_data: not_remarried_data) }

      it 'sets remarriage checkboxes correctly' do
        expect(payload['REMARRIED_AFTER_VET_DEATH_YES']).to be false
        expect(payload['REMARRIED_AFTER_VET_DEATH_NO']).to be true
      end

      it 'has nil remarriage fields' do
        expect(payload['DATE_OF_MARRIAGE']).to be_nil
        expect(payload['VETERAN_NAME']).to be_nil
        expect(payload['SSN']).to be_nil
      end
    end

    context 'when spouse is not a veteran' do
      let(:non_veteran_spouse_data) do
        data = JSON.parse(form_data)
        data['remarriage']['spouse_is_veteran'] = false
        data.to_json
      end

      let(:form_submission) { create(:form_submission, form_type: '21P-0537', form_data: non_veteran_spouse_data) }

      it 'sets spouse veteran checkboxes correctly' do
        expect(payload['SPOUSE_VET_YES']).to be false
        expect(payload['SPOUSE_VET_NO']).to be true
      end
    end

    context 'with minimal remarriage data' do
      let(:minimal_data) do
        data = JSON.parse(form_data)
        data['remarriage'] = {
          'date_of_marriage' => { 'month' => '01', 'day' => '20', 'year' => '2020' },
          'spouse_name' => { 'first' => 'Bob', 'last' => 'Spouse' }
        }
        data.to_json
      end

      let(:form_submission) { create(:form_submission, form_type: '21P-0537', form_data: minimal_data) }

      it 'handles missing middle initial gracefully' do
        expect(payload['SPOUSE_MIDDLE_INITIAL']).to be_nil
        expect(payload['VETERAN_NAME']).to eq('Bob Spouse')
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
