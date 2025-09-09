# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA8794, form: :education_benefits, type: :model do
  subject { described_class.new(education_benefits_claim) }

  let(:education_benefits_claim) { create(:va8794).education_benefits_claim }
  let(:parsed_form) { education_benefits_claim.parsed_form }

  describe '#designating_official_name' do
    context 'when designating official data is present' do
      it 'returns the full name object' do
        expect(subject.designating_official_name).to eq({
                                                          'first' => 'John',
                                                          'middle' => 'A',
                                                          'last' => 'Doe'
                                                        })
      end
    end

    context 'when designating official data is missing' do
      before do
        allow(education_benefits_claim).to receive(:parsed_form).and_return({})
      end

      it 'raises a NoMethodError' do
        expect { subject.designating_official_name }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#designating_official_title' do
    context 'when title is present' do
      it 'returns the title' do
        expect(subject.designating_official_title).to eq('Designating Official')
      end
    end

    context 'when designating official data is missing' do
      before do
        allow(education_benefits_claim).to receive(:parsed_form).and_return({})
      end

      it 'raises a NoMethodError' do
        expect { subject.designating_official_title }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#designating_official_email' do
    context 'when email is present' do
      it 'returns the email address' do
        expect(subject.designating_official_email).to eq('john.doe@example.com')
      end
    end

    context 'when designating official data is missing' do
      before do
        allow(education_benefits_claim).to receive(:parsed_form).and_return({})
      end

      it 'raises a NoMethodError' do
        expect { subject.designating_official_email }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#institution_name' do
    context 'when institution name is present' do
      it 'returns the institution name' do
        expect(subject.institution_name).to eq('Test University')
      end
    end

    context 'when institution details are missing' do
      before do
        allow(education_benefits_claim).to receive(:parsed_form).and_return({})
      end

      it 'raises a NoMethodError' do
        expect { subject.institution_name }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#facility_code' do
    context 'when facility code is present' do
      it 'returns the facility code' do
        expect(subject.facility_code).to eq('12345678')
      end
    end

    context 'when institution details are missing' do
      before do
        allow(education_benefits_claim).to receive(:parsed_form).and_return({})
      end

      it 'raises a NoMethodError' do
        expect { subject.facility_code }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#va_facility_code?' do
    context 'when hasVaFacilityCode is true' do
      it 'returns true' do
        expect(subject.va_facility_code?).to be true
      end
    end

    context 'when hasVaFacilityCode is false' do
      before do
        parsed_form['institutionDetails']['hasVaFacilityCode'] = false
        allow(education_benefits_claim).to receive(:parsed_form).and_return(parsed_form)
      end

      it 'returns false' do
        expect(subject.va_facility_code?).to be false
      end
    end

    context 'when institution details are missing' do
      before do
        allow(education_benefits_claim).to receive(:parsed_form).and_return({})
      end

      it 'raises a NoMethodError' do
        expect { subject.va_facility_code? }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#primary_official_name' do
    context 'when primary official name is present' do
      it 'returns the full name object' do
        expect(subject.primary_official_name).to eq({
                                                      'first' => 'Jane',
                                                      'middle' => 'B',
                                                      'last' => 'Smith'
                                                    })
      end
    end

    context 'when primary official details are missing' do
      before do
        allow(education_benefits_claim).to receive(:parsed_form).and_return({})
      end

      it 'raises a NoMethodError' do
        expect { subject.primary_official_name }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#primary_official_title' do
    context 'when title is present' do
      it 'returns the title' do
        expect(subject.primary_official_title).to eq('Primary Certifying Official')
      end
    end

    context 'when primary official details are missing' do
      before do
        allow(education_benefits_claim).to receive(:parsed_form).and_return({})
      end

      it 'raises a NoMethodError' do
        expect { subject.primary_official_title }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#primary_official_email' do
    context 'when email is present' do
      it 'returns the email address' do
        expect(subject.primary_official_email).to eq('jane.smith@example.com')
      end
    end

    context 'when primary official details are missing' do
      before do
        allow(education_benefits_claim).to receive(:parsed_form).and_return({})
      end

      it 'raises a NoMethodError' do
        expect { subject.primary_official_email }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#training_completion_date' do
    context 'when training completion date is present' do
      it 'returns the training completion date' do
        expect(subject.training_completion_date).to eq('2024-03-15')
      end
    end

    context 'when primary official training is missing' do
      before do
        allow(education_benefits_claim).to receive(:parsed_form).and_return({})
      end

      it 'raises a NoMethodError' do
        expect { subject.training_completion_date }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#training_exempt' do
    context 'when training exempt is present' do
      it 'returns the training exempt value' do
        expect(subject.training_exempt).to be false
      end
    end

    context 'when primary official training is missing' do
      before do
        allow(education_benefits_claim).to receive(:parsed_form).and_return({})
      end

      it 'raises a NoMethodError' do
        expect { subject.training_exempt }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#va_education_benefits?' do
    context 'when hasVaEducationBenefits is true' do
      it 'returns true' do
        expect(subject.va_education_benefits?).to be true
      end
    end

    context 'when hasVaEducationBenefits is false' do
      before do
        parsed_form['primaryOfficialBenefitStatus']['hasVaEducationBenefits'] = false
        allow(education_benefits_claim).to receive(:parsed_form).and_return(parsed_form)
      end

      it 'returns false' do
        expect(subject.va_education_benefits?).to be false
      end
    end

    context 'when primary official benefit status is missing' do
      before do
        allow(education_benefits_claim).to receive(:parsed_form).and_return({})
      end

      it 'raises a NoMethodError' do
        expect { subject.va_education_benefits? }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#additional_certifying_officials' do
    context 'when additional certifying officials are present' do
      before do
        parsed_form['additionalCertifyingOfficials'] = [
          { 'name' => 'Official 1' },
          { 'name' => 'Official 2' }
        ]
        allow(education_benefits_claim).to receive(:parsed_form).and_return(parsed_form)
      end

      it 'returns the array of additional certifying officials' do
        expect(subject.additional_certifying_officials).to eq([
                                                                { 'name' => 'Official 1' },
                                                                { 'name' => 'Official 2' }
                                                              ])
      end
    end

    context 'when additional certifying officials are not present' do
      it 'returns an empty array' do
        expect(subject.additional_certifying_officials).to eq([])
      end
    end
  end

  describe '#read_only_certifying_official?' do
    context 'when hasReadOnlyCertifyingOfficial is true' do
      before do
        parsed_form['hasReadOnlyCertifyingOfficial'] = true
        allow(education_benefits_claim).to receive(:parsed_form).and_return(parsed_form)
      end

      it 'returns true' do
        expect(subject.read_only_certifying_official?).to be true
      end
    end

    context 'when hasReadOnlyCertifyingOfficial is false' do
      before do
        parsed_form['hasReadOnlyCertifyingOfficial'] = false
        allow(education_benefits_claim).to receive(:parsed_form).and_return(parsed_form)
      end

      it 'returns false' do
        expect(subject.read_only_certifying_official?).to be false
      end
    end

    context 'when hasReadOnlyCertifyingOfficial is not present' do
      it 'returns nil' do
        expect(subject.read_only_certifying_official?).to be_nil
      end
    end
  end

  describe '#read_only_certifying_officials' do
    context 'when read only certifying officials are present' do
      before do
        parsed_form['readOnlyCertifyingOfficial'] = [
          { 'name' => 'Read Only Official 1' },
          { 'name' => 'Read Only Official 2' }
        ]
        allow(education_benefits_claim).to receive(:parsed_form).and_return(parsed_form)
      end

      it 'returns the array of read only certifying officials' do
        expect(subject.read_only_certifying_officials).to eq([
                                                               { 'name' => 'Read Only Official 1' },
                                                               { 'name' => 'Read Only Official 2' }
                                                             ])
      end
    end

    context 'when read only certifying officials are not present' do
      it 'returns an empty array' do
        expect(subject.read_only_certifying_officials).to eq([])
      end
    end
  end

  describe '#remarks' do
    context 'when remarks are present' do
      before do
        parsed_form['remarks'] = 'These are some remarks about the form.'
        allow(education_benefits_claim).to receive(:parsed_form).and_return(parsed_form)
      end

      it 'returns the remarks' do
        expect(subject.remarks).to eq('These are some remarks about the form.')
      end
    end

    context 'when remarks are not present' do
      it 'returns nil' do
        expect(subject.remarks).to be_nil
      end
    end
  end

  describe '#statement_of_truth_signature' do
    context 'when signature is present' do
      it 'returns the signature' do
        expect(subject.statement_of_truth_signature).to eq('John A Doe')
      end
    end

    context 'when signature is not present' do
      before do
        allow(education_benefits_claim).to receive(:parsed_form).and_return({})
      end

      it 'returns nil' do
        expect(subject.statement_of_truth_signature).to be_nil
      end
    end
  end

  describe '#date_signed' do
    context 'when date signed is present' do
      it 'returns the date signed' do
        expect(subject.date_signed).to eq('2024-03-15')
      end
    end

    context 'when date signed is not present' do
      before do
        allow(education_benefits_claim).to receive(:parsed_form).and_return({})
      end

      it 'returns nil' do
        expect(subject.date_signed).to be_nil
      end
    end
  end

  describe '#header_form_type' do
    it 'returns the correct header form type' do
      expect(subject.header_form_type).to eq('V8794')
    end
  end
end
