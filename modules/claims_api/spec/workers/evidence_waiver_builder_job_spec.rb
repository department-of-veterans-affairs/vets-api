# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::EvidenceWaiverBuilderJob, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:ews) { create(:claims_api_evidence_waiver_submission, :with_full_headers_tamara) }

  describe 'generating the filled and signed pdf' do
    it 'generates the pdf to match example' do
      allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
      expect(ClaimsApi::EvidenceWaiver).to receive(:new).and_call_original
      expect_any_instance_of(ClaimsApi::EvidenceWaiver).to receive(:construct).and_call_original

      subject.new.perform(ews.id)
    end
  end
end
