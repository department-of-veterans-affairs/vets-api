# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'

describe ClaimsApi::DisabilityCompensation::DisabilityDocumentService do
  subject { described_class.new }

  let(:claim) { create(:auto_established_claim, evss_id: 600_400_688, id: '581128c6-ad08-4b1e-8b82-c3640e829fb3') }
  let(:body) { 'test body' }

  before do
    allow_any_instance_of(ClaimsApi::V2::BenefitsDocuments::Service)
      .to receive(:get_auth_token).and_return('some-value-here')
  end

  describe 'disability comp (doc_type: L122)' do
    let(:veteran_name) { 'John_Smith' }
    let(:claim_id) { '600_400_688' }
    let(:form_name) { '526EZ' }
    let(:original_filename) { '' }
    let(:doc_type) { 'L122' }

    it 'generates the correct filename for L122' do
      result = subject.send(:generate_file_name, veteran_name:, claim_id:, form_name:, original_filename:)
      expect(result).to be_a String
      expect(result).to eq 'John_Smith_600_400_688_526EZ.pdf'
    end
  end

  describe 'other attachments (doc_type: L023)' do
    let(:veteran_name) { 'John_Smith' }
    let(:claim_id) { '600_400_688' }
    let(:form_name) { 'supporting' }
    let(:original_filename) { 'original_filename_IRT56SX99qs.pdf' }
    let(:doc_type) { 'L023' }

    it 'generates the correct filename for L023' do
      result = subject.send(:generate_file_name, veteran_name:, claim_id:, form_name:, original_filename:)
      expect(result).to be_a String
      expect(result).to eq 'John_Smith_600_400_688_original_filename.pdf'
    end
  end
end
