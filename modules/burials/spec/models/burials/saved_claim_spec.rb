# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Burials::SavedClaim do
  subject { described_class.new }

  let(:instance) { build(:burials_saved_claim) }

  it 'responds to #confirmation_number' do
    expect(subject.confirmation_number).to eq(subject.guid)
  end

  it 'has necessary constants' do
    expect(described_class).to have_constant(:FORM)
  end

  it 'descends from saved_claim' do
    expect(described_class.ancestors).to include(SavedClaim)
  end

  describe '#process_attachments!' do
    it 'does NOT start a job to submit the saved claim via Benefits Intake' do
      expect(Lighthouse::SubmitBenefitsIntakeClaim).not_to receive(:perform_async)
      instance.process_attachments!
    end
  end

  context 'a record is processed through v2' do
    it 'inherits init callsbacks from saved_claim' do
      expect(subject.form_id).to eq('21P-530EZ')
      expect(subject.guid).not_to be_nil
      expect(subject.type).to eq(described_class.to_s)
    end

    context 'validates against the form schema' do
      before do
        expect(instance.valid?).to be(true)
        expect(JSON::Validator).to receive(:fully_validate).once.and_call_original
      end

      # NOTE: We assume all forms have the privacyAgreementAccepted element. Obviously.
      it 'rejects forms with missing elements' do
        bad_form = instance.parsed_form.deep_dup
        bad_form.delete('privacyAgreementAccepted')
        instance.form = bad_form.to_json
        instance.remove_instance_variable(:@parsed_form)
        expect(instance.valid?).to be(false)
        expect(instance.errors.full_messages.size).to eq(1)
        expect(instance.errors.full_messages).to include(/privacyAgreementAccepted/)
      end
    end
  end

  describe '#email' do
    it 'returns the users email' do
      expect(instance.email).to eq('foo@foo.com')
    end
  end

  describe '#benefits_claimed' do
    it 'returns a full array of values' do
      benefits_claimed = instance.benefits_claimed
      expected = ['Burial Allowance', 'Plot Allowance', 'Transportation']

      expect(benefits_claimed.length).to eq(3)
      expect(benefits_claimed).to eq(expected)
    end

    it 'returns at least an empty array' do
      form = instance.parsed_form

      form = form.merge({ 'transportation' => false })
      claim = build(:burials_saved_claim, form: form.to_json)
      benefits_claimed = claim.benefits_claimed
      expected = ['Burial Allowance', 'Plot Allowance']
      expect(benefits_claimed.length).to eq(2)
      expect(benefits_claimed).to eq(expected)

      form = form.merge({ 'plotAllowance' => false })
      claim = build(:burials_saved_claim, form: form.to_json)
      benefits_claimed = claim.benefits_claimed
      expected = ['Burial Allowance']
      expect(benefits_claimed.length).to eq(1)
      expect(benefits_claimed).to eq(expected)

      form = form.merge({ 'burialAllowance' => false })
      claim = build(:burials_saved_claim, form: form.to_json)
      benefits_claimed = claim.benefits_claimed
      expected = []
      expect(benefits_claimed.length).to eq(0)
      expect(benefits_claimed).to eq(expected)
    end
  end

  describe '#process_pdf' do
    let(:pdf_path) { 'path/to/original.pdf' }
    let(:timestamp) { '2025-01-14T12:00:00Z' }
    let(:form_id) { '21P-530EZ' }
    let(:processed_pdf_path) { 'path/to/processed.pdf' }
    let(:renamed_path) { "tmp/pdfs/#{form_id}__final.pdf" }
    let(:pdf_utilities_instance) { instance_double(PDFUtilities::DatestampPdf) }

    before do
      allow(PDFUtilities::DatestampPdf).to receive(:new).with(pdf_path).and_return(pdf_utilities_instance)
      allow(pdf_utilities_instance).to receive(:run).and_return(processed_pdf_path)
      allow(File).to receive(:rename).with(processed_pdf_path, renamed_path)
    end

    it 'processes the PDF and renames the file correctly' do
      result = subject.process_pdf(pdf_path, timestamp, form_id)

      expect(PDFUtilities::DatestampPdf).to have_received(:new).with(pdf_path)
      expect(pdf_utilities_instance).to have_received(:run).with(
        text: 'Application Submitted on va.gov',
        x: 400,
        y: 675,
        text_only: true,
        timestamp: timestamp,
        page_number: 6,
        template: "lib/pdf_fill/forms/pdfs/#{form_id}.pdf",
        multistamp: true
      )
      expect(File).to have_received(:rename).with(processed_pdf_path, renamed_path)
      expect(result).to eq(renamed_path)
    end
  end

  describe '#business_line' do
    it 'returns the correct business line' do
      expect(subject.business_line).to eq('NCA')
    end
  end
end
