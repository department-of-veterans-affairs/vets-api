# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::AppointmentsReasonCodeService do
  describe '#extract_reason_code_fields' do
    it 'returns without modification if no reason code text exists' do
      appt = build(:appointment_form_v2, :va_proposed_base).attributes
      subject.extract_reason_code_fields(appt)
      expect(appt[:contact]).to eq({})
      expect(appt[:patient_comments]).to be_nil
      expect(appt[:reason_for_appointment]).to be_nil
      expect(appt[:preferred_dates]).to be_nil
      expect(appt[:preferred_modality]).to be_nil
    end

    it 'returns without modification if no valid reason code text fields exists' do
      appt = build(:appointment_form_v2, :va_proposed_invalid_reason_code_text).attributes
      subject.extract_reason_code_fields(appt)
      expect(appt[:contact]).to eq({})
      expect(appt[:patient_comments]).to be_nil
      expect(appt[:reason_for_appointment]).to be_nil
      expect(appt[:preferred_dates]).to be_nil
      expect(appt[:preferred_modality]).to be_nil
    end

    it 'returns without modification for cc request' do
      appt = build(:appointment_form_v2, :community_cares_valid_reason_code_text).attributes
      subject.extract_reason_code_fields(appt)
      expect(appt[:contact]).to eq({})
      expect(appt[:patient_comments]).to eq('colon:in:comment')
      expect(appt[:reason_for_appointment]).to be_nil
      expect(appt[:preferred_dates]).to be_nil
      expect(appt[:preferred_modality]).to be_nil
    end

    it 'returns without modification for cc booked' do
      appt = build(:appointment_form_v2, :ds_cc_booked_valid_reason_code_text).attributes
      subject.extract_reason_code_fields(appt)
      expect(appt[:contact]).to eq({})
      expect(appt[:patient_comments]).to eq('colon:in:comment')
      expect(appt[:reason_for_appointment]).to be_nil
      expect(appt[:preferred_dates]).to be_nil
      expect(appt[:preferred_modality]).to be_nil
    end

    it 'extract valid reason code fields for booked va direct scheduling appointments' do
      appt = build(:appointment_form_v2, :va_booked_valid_reason_code_text).attributes
      subject.extract_reason_code_fields(appt)
      expect(appt[:contact]).to eq({})
      expect(appt[:patient_comments]).to eq('colon:in:comment')
      expect(appt[:reason_for_appointment]).to eq('Routine/Follow-up')
      expect(appt[:preferred_dates]).to be_nil
      expect(appt[:preferred_modality]).to be_nil
    end

    it 'extract valid reason code fields for cancelled va direct scheduling appointments' do
      appt = build(:appointment_form_v2, :va_cancelled_valid_reason_code_text).attributes
      subject.extract_reason_code_fields(appt)
      expect(appt[:contact]).to eq({})
      expect(appt[:patient_comments]).to eq('colon:in:comment')
      expect(appt[:reason_for_appointment]).to eq('Routine/Follow-up')
      expect(appt[:preferred_dates]).to be_nil
      expect(appt[:preferred_modality]).to be_nil
    end

    it 'extract valid reason code fields for va request' do
      appt = build(:appointment_form_v2, :va_proposed_valid_reason_code_text).attributes
      subject.extract_reason_code_fields(appt)
      expect(appt[:contact][:telecom][0]).to eq({ type: 'phone', value: '6195551234' })
      expect(appt[:contact][:telecom][1]).to eq({ type: 'email', value: 'myemail72585885@unattended.com' })
      expect(appt[:patient_comments]).to eq('colon:in:comment')
      expect(appt[:reason_for_appointment]).to eq('Routine/Follow-up')
      expect(appt[:preferred_dates]).to eq(['Wed, June 26, 2024 in the morning',
                                            'Wed, June 26, 2024 in the afternoon'])
      expect(appt[:preferred_modality]).to eq('In person')
    end

    context 'when there are valid and invalid reason code fields' do
      it 'extract only valid reason code fields for va request' do
        appt = build(:appointment_form_v2, :va_proposed_valid_and_invalid_reason_code_text).attributes
        subject.extract_reason_code_fields(appt)
        expect(appt[:contact][:telecom][0]).to eq({ type: 'phone', value: '6195551234' })
        expect(appt[:contact][:telecom][1]).to eq({ type: 'email', value: 'myemail72585885@unattended.com' })
        expect(appt[:patient_comments]).to be_nil
        expect(appt[:reason_for_appointment]).to be_nil
        expect(appt[:preferred_dates]).to eq(['Wed, June 26, 2024 in the morning',
                                              'Wed, June 26, 2024 in the afternoon'])
        expect(appt[:preferred_modality]).to eq('In person')
      end
    end
  end

  describe '#parse_reason_code_text' do
    [
      ['', {}],
      ['key', {}],
      ['key:', {}],
      ['key:value', { 'key' => 'value' }],
      [' key : value ', { 'key' => 'value' }],
      ['key:value:invalid', {}],
      ['comments', {}],
      ['comments:', {}],
      ['comments:text', { 'comments' => 'text' }],
      [' comments : text ', { 'comments' => 'text' }],
      ['comments:key:value', { 'comments' => 'key:value' }],
      [' comments : key : value ', { 'comments' => 'key : value' }]
    ].each do |input, output|
      it "#{input} returns #{output}" do
        expect(subject.send(:parse_reason_code_text, input)).to eq(output)
      end
    end
  end

  describe '#extract_reason_for_appointment' do
    [
      ['', nil],
      ['NON_EXISTENT', nil],
      ['ROUTINEVISIT', 'Routine/Follow-up'],
      ['MEDICALISSUE', 'New medical issue'],
      ['QUESTIONMEDS', 'Medication concern'],
      ['OTHER_REASON', 'My reason isn’t listed']
    ].each do |input, output|
      it "#{input} returns #{output}" do
        input_hash = {}
        input_hash['reason code'] = input
        expect(subject.send(:extract_reason_for_appointment, input_hash)).to eq(output)
      end
    end
  end

  describe '#extract_preferred_modality' do
    [
      ['', nil],
      ['NON_EXISTENT', nil],
      ['FACE TO FACE', 'In person'],
      ['VIDEO', 'Video'],
      ['TELEPHONE', 'Phone']
    ].each do |input, output|
      it "#{input} returns #{output}" do
        input_hash = {}
        input_hash['preferred modality'] = input
        expect(subject.send(:extract_preferred_modality, input_hash)).to eq(output)
      end
    end
  end

  describe '#extract_preferred_dates' do
    [
      ['', nil],
      ['06/26/2024 AM', ['Wed, June 26, 2024 in the morning']],
      ['06/26/2024 PM', ['Wed, June 26, 2024 in the afternoon']],
      ['06/26/2024 AM,06/26/2024 PM', ['Wed, June 26, 2024 in the morning', 'Wed, June 26, 2024 in the afternoon']],
      ['09/06/2024 PM', ['Fri, September 6, 2024 in the afternoon']]
    ].each do |input, output|
      it "#{input} returns #{output}" do
        input_hash = {}
        input_hash['preferred dates'] = input
        expect(subject.send(:extract_preferred_dates, input_hash)).to eq(output)
      end
    end
  end
end
