# frozen_string_literal: true

require 'rails_helper'
require 'form_intake/mappers/base_mapper'
require 'form_intake/mappers/vba_21p_0537_mapper'

RSpec.describe FormIntake::Mappers::VBA21p0537Mapper do
  let(:form_data) do
    {
      'formNumber' => '21P-0537',
      'veteran' => {
        'fullName' => {
          'first' => 'John',
          'middle' => 'M',
          'last' => 'Veteran'
        },
        'ssn' => {
          'first3' => '987',
          'middle2' => '65',
          'last4' => '4321'
        },
        'vaFileNumber' => '123456789'
      },
      'recipient' => {
        'fullName' => {
          'first' => 'Jane',
          'middle' => 'R',
          'last' => 'Recipient'
        },
        'phone' => {
          'daytime' => {
            'areaCode' => '123',
            'prefix' => '456',
            'lineNumber' => '7890'
          },
          'evening' => {
            'areaCode' => '321',
            'prefix' => '654',
            'lineNumber' => '0987'
          }
        },
        'email' => 'jane.recipient@email.com',
        'signature' => 'Jane R Recipient',
        'signatureDate' => {
          'month' => '09',
          'day' => '19',
          'year' => '2025'
        }
      },
      'inReplyReferTo' => '987654321',
      'hasRemarried' => true,
      'remarriage' => {
        'dateOfMarriage' => {
          'month' => '01',
          'day' => '20',
          'year' => '2020'
        },
        'spouseName' => {
          'first' => 'Bob',
          'middle' => 'T',
          'last' => 'Spouse'
        },
        'spouseDateOfBirth' => {
          'month' => '01',
          'day' => '17',
          'year' => '1978'
        },
        'spouseIsVeteran' => true,
        'ageAtMarriage' => '50',
        'spouseSSN' => {
          'first3' => '555',
          'middle2' => '66',
          'last4' => '7777'
        },
        'spouseVAFileNumber' => '888888888',
        'hasTerminated' => false,
        'terminationDate' => {
          'month' => '',
          'day' => '',
          'year' => ''
        },
        'terminationReason' => ''
      }
    }.to_json
  end

  let(:form_submission) { create(:form_submission, form_type: '21P-0537', form_data:) }
  let(:benefits_intake_uuid) { 'uuid-537-012' }
  let(:mapper) { described_class.new(form_submission, benefits_intake_uuid) }

  describe '#to_gcio_payload' do
    let(:payload) { mapper.to_gcio_payload }

    it 'includes form metadata' do
      expect(payload[:form_number]).to eq('21P-0537')
      expect(payload[:benefits_intake_uuid]).to eq('uuid-537-012')
      expect(payload[:submission_id]).to eq(form_submission.id)
      expect(payload[:submitted_at]).to be_present
    end

    it 'maps veteran information' do
      expect(payload[:veteran][:first_name]).to eq('John')
      expect(payload[:veteran][:middle_name]).to eq('M')
      expect(payload[:veteran][:last_name]).to eq('Veteran')
      expect(payload[:veteran][:ssn]).to eq('987654321')
      expect(payload[:veteran][:va_file_number]).to eq('123456789')
    end

    it 'maps recipient information' do
      expect(payload[:recipient][:first_name]).to eq('Jane')
      expect(payload[:recipient][:middle_name]).to eq('R')
      expect(payload[:recipient][:last_name]).to eq('Recipient')
      expect(payload[:recipient][:email]).to eq('jane.recipient@email.com')
      expect(payload[:recipient][:signature]).to eq('Jane R Recipient')
      expect(payload[:recipient][:signature_date]).to eq('09/19/2025')
    end

    it 'maps recipient phone numbers' do
      expect(payload[:recipient][:phone][:daytime]).to eq('1234567890')
      expect(payload[:recipient][:phone][:evening]).to eq('3216540987')
    end

    it 'includes remarriage status' do
      expect(payload[:has_remarried]).to be true
    end

    it 'maps remarriage details' do
      expect(payload[:remarriage][:date_of_marriage]).to eq('01/20/2020')
      expect(payload[:remarriage][:spouse_name][:first]).to eq('Bob')
      expect(payload[:remarriage][:spouse_name][:middle]).to eq('T')
      expect(payload[:remarriage][:spouse_name][:last]).to eq('Spouse')
      expect(payload[:remarriage][:spouse_date_of_birth]).to eq('01/17/1978')
      expect(payload[:remarriage][:spouse_is_veteran]).to be true
      expect(payload[:remarriage][:age_at_marriage]).to eq('50')
      expect(payload[:remarriage][:spouse_ssn]).to eq('555667777')
      expect(payload[:remarriage][:spouse_va_file_number]).to eq('888888888')
      expect(payload[:remarriage][:has_terminated]).to be false
    end

    it 'includes in reply refer to' do
      expect(payload[:in_reply_refer_to]).to eq('987654321')
    end

    it 'does not include termination date when marriage not terminated' do
      expect(payload[:remarriage]).not_to have_key(:termination_date)
    end

    context 'when recipient has not remarried' do
      let(:not_remarried_data) do
        data = JSON.parse(form_data)
        data['hasRemarried'] = false
        data.delete('remarriage')
        data.to_json
      end

      let(:form_submission) { create(:form_submission, form_type: '21P-0537', form_data: not_remarried_data) }

      it 'includes remarriage status as false' do
        expect(payload[:has_remarried]).to be false
      end

      it 'does not include remarriage section' do
        expect(payload).not_to have_key(:remarriage)
      end
    end

    context 'when remarriage has terminated' do
      let(:terminated_data) do
        data = JSON.parse(form_data)
        data['remarriage']['hasTerminated'] = true
        data['remarriage']['terminationDate'] = {
          'month' => '06',
          'day' => '15',
          'year' => '2023'
        }
        data['remarriage']['terminationReason'] = 'Death of spouse'
        data.to_json
      end

      let(:form_submission) { create(:form_submission, form_type: '21P-0537', form_data: terminated_data) }

      it 'includes termination information' do
        expect(payload[:remarriage][:has_terminated]).to be true
        expect(payload[:remarriage][:termination_date]).to eq('06/15/2023')
        expect(payload[:remarriage][:termination_reason]).to eq('Death of spouse')
      end
    end

    context 'when recipient has only daytime phone' do
      let(:daytime_only_data) do
        data = JSON.parse(form_data)
        data['recipient']['phone'].delete('evening')
        data.to_json
      end

      let(:form_submission) { create(:form_submission, form_type: '21P-0537', form_data: daytime_only_data) }

      it 'includes only daytime phone' do
        expect(payload[:recipient][:phone][:daytime]).to eq('1234567890')
        expect(payload[:recipient][:phone]).not_to have_key(:evening)
      end
    end

    context 'with minimal data' do
      let(:minimal_form_data) do
        {
          'formNumber' => '21P-0537',
          'veteran' => {
            'fullName' => { 'first' => 'John', 'last' => 'Doe' }
          },
          'recipient' => {
            'fullName' => { 'first' => 'Jane', 'last' => 'Doe' },
            'signature' => 'Jane Doe'
          },
          'hasRemarried' => false
        }.to_json
      end

      let(:form_submission) { create(:form_submission, form_type: '21P-0537', form_data: minimal_form_data) }

      it 'handles missing optional fields gracefully' do
        expect { payload }.not_to raise_error
        expect(payload[:veteran][:first_name]).to eq('John')
        expect(payload[:veteran]).not_to have_key(:ssn)
        expect(payload[:recipient][:first_name]).to eq('Jane')
        expect(payload).not_to have_key(:remarriage)
      end
    end

    context 'when veteran VA file number is empty string' do
      let(:empty_file_number_data) do
        data = JSON.parse(form_data)
        data['veteran']['vaFileNumber'] = ''
        data.to_json
      end

      let(:form_submission) { create(:form_submission, form_type: '21P-0537', form_data: empty_file_number_data) }

      it 'does not include va_file_number in payload' do
        expect(payload[:veteran]).not_to have_key(:va_file_number)
      end
    end

    context 'when spouse is not a veteran' do
      let(:non_veteran_spouse_data) do
        data = JSON.parse(form_data)
        data['remarriage']['spouseIsVeteran'] = false
        data['remarriage'].delete('spouseVAFileNumber')
        data.to_json
      end

      let(:form_submission) { create(:form_submission, form_type: '21P-0537', form_data: non_veteran_spouse_data) }

      it 'maps spouse_is_veteran as false' do
        expect(payload[:remarriage][:spouse_is_veteran]).to be false
      end

      it 'does not include spouse VA file number' do
        expect(payload[:remarriage]).not_to have_key(:spouse_va_file_number)
      end
    end

    context 'when recipient has no phone' do
      let(:no_phone_data) do
        data = JSON.parse(form_data)
        data['recipient'].delete('phone')
        data.to_json
      end

      let(:form_submission) { create(:form_submission, form_type: '21P-0537', form_data: no_phone_data) }

      it 'does not include phone in payload' do
        expect(payload[:recipient]).not_to have_key(:phone)
      end
    end
  end
end

