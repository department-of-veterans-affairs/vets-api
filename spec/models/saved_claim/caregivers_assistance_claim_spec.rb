# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::CaregiversAssistanceClaim do
  describe '#to_pdf' do
    it 'converts form to pdf' do
      claim = build(:caregivers_assistance_claim)
      expected_file_path = 'tmp/pdfs/my_claim.pdf'

      expect(PdfFill::Filler).to receive(:fill_form).with(claim).once.and_return(expected_file_path)

      result = claim.to_pdf
      expect(result).to eq(expected_file_path)
    end
  end

  describe '#process_attachments!' do
    it 'raises a NotImplementedError' do
      expect { subject.process_attachments! }.to raise_error(NotImplementedError)
    end
  end

  describe '#regional_office' do
    it 'returns empty array' do
      expect(subject.regional_office).to eq([])
    end
  end

  describe '#form_subjects' do
    it 'returns a list of subjects present in #parsed_form' do
      claim_1 = described_class.new(form: {
        "veteran": {}
      }.to_json)
      expect(claim_1.form_subjects).to eq(%w[veteran])

      claim_2 = described_class.new(form: {
        "veteran": {},
        "primaryCaregiver": {}
      }.to_json)
      expect(claim_2.form_subjects).to eq(%w[veteran primaryCaregiver])

      claim_3 = described_class.new(form: {
        "veteran": {},
        "primaryCaregiver": {},
        "secondaryCaregiverOne": {}
      }.to_json)
      expect(claim_3.form_subjects).to eq(%w[veteran primaryCaregiver secondaryCaregiverOne])

      claim_4 = described_class.new(form: {
        "veteran": {},
        "primaryCaregiver": {},
        "secondaryCaregiverOne": {},
        "secondaryCaregiverTwo": {}
      }.to_json)
      expect(claim_4.form_subjects).to eq(%w[veteran primaryCaregiver secondaryCaregiverOne secondaryCaregiverTwo])
    end

    context 'when no subjects are present' do
      it 'returns a an empty array' do
        expect(subject.form_subjects).to eq([])
      end
    end
  end

  describe '#veteran_data' do
    it 'returns the veteran\'s data from the form as a hash' do
      subjects_data = { 'myName' => 'Veteran' }
      subject = described_class.new(
        form: {
          'veteran' => subjects_data
        }.to_json
      )

      expect(subject.veteran_data).to eq(subjects_data)
    end

    context 'when no data present' do
      it 'returns nil' do
        expect(subject.veteran_data).to eq(nil)
      end
    end
  end

  describe '#primary_caregiver_data' do
    it 'returns the veteran\'s data from the form as a hash' do
      subjects_data = { 'myName' => 'Primary Caregiver' }

      subject = described_class.new(
        form: {
          'primaryCaregiver' => subjects_data
        }.to_json
      )

      expect(subject.primary_caregiver_data).to eq(subjects_data)
    end

    context 'when no data present' do
      it 'returns nil' do
        expect(subject.primary_caregiver_data).to eq(nil)
      end
    end
  end

  describe '#secondary_caregiver_one_data' do
    it 'returns the veteran\'s data from the form as a hash' do
      subjects_data = { 'myName' => 'Secondary Caregiver I' }

      subject = described_class.new(
        form: {
          'secondaryCaregiverOne' => subjects_data
        }.to_json
      )

      expect(subject.secondary_caregiver_one_data).to eq(subjects_data)
    end

    context 'when no data present' do
      it 'returns nil' do
        expect(subject.secondary_caregiver_one_data).to eq(nil)
      end
    end
  end

  describe '#secondary_caregiver_two_data' do
    it 'returns the veteran\'s data from the form as a hash' do
      subjects_data = { 'myName' => 'Secondary Caregiver II' }

      subject = described_class.new(
        form: {
          'secondaryCaregiverTwo' => subjects_data
        }.to_json
      )

      expect(subject.secondary_caregiver_two_data).to eq(subjects_data)
    end

    context 'when no data present' do
      it 'returns nil' do
        expect(subject.secondary_caregiver_two_data).to eq(nil)
      end
    end
  end
end
