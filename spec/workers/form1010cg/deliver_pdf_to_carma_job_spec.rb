# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::DeliverPdfToCARMAJob do
  it 'inherits Sidekiq::Worker' do
    expect(described_class.ancestors).to include(Sidekiq::Worker)
  end

  describe '#perform' do
    let(:claim_guid) { SecureRandom.uuid }
    let(:claim) { build(:caregivers_assistance_claim, guid: claim_guid) }
    let(:submission) { build(:form1010cg_submission, claim_guid: claim_guid) }

    before do
      submission.claim = claim
      submission.save!
    end

    after do
      claim.destroy
      submission.destroy
    end

    it 'requires a claim_guid' do
      expect { subject.perform }.to raise_error(ArgumentError) do |error|
        expect(error.message).to eq('wrong number of arguments (given 0, expected 1)')
      end
    end

    context 'when submission is not found' do
      it 'raises error' do
        expect { subject.perform(SecureRandom.uuid) }.to raise_error(ActiveRecord::RecordNotFound) do |error|
          expect(error.message).to include('Couldn\'t find Form1010cg::Submission')
        end
      end
    end

    context 'when claim is not found' do
      let(:expected_exception_class) { described_class::MissingClaimException }

      before do
        claim.delete # delete the claim but not the submission
      end

      it 'raises error' do
        expect { subject.perform(claim_guid) }.to raise_error(expected_exception_class) do |error|
          expect(error.message).to eq('Could not find a claim associated to this submission')
        end
      end
    end

    context 'when PDF generation fails' do
      let(:pdf_generation_exception) do
        class MyPdfError < StandardError; end
        MyPdfError.new('PDF could not be generated')
      end

      before do
        expect_any_instance_of(SavedClaim::CaregiversAssistanceClaim).to receive(
          :to_pdf
        ).and_raise(
          pdf_generation_exception
        )
      end

      it 'raises error' do
        expect { subject.perform(claim_guid) }.to raise_error(pdf_generation_exception.class) do |error|
          expect(error.message).to eq(pdf_generation_exception.message)
        end
      end
    end

    it 'delivers a PDF to carma with the Form1010cg::Service' do
    end
  end
end
