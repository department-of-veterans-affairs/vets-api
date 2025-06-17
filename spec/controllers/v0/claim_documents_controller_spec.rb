# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::ClaimDocumentsController, type: :controller do
  let(:user) { build(:user, :loa3) }
  let(:benefits_intake) { instance_double(BenefitsIntake::Service) }
  let(:valid_file) { fixture_file_upload('spec/fixtures/files/doctors-note.pdf', 'application/pdf') }
  let(:empty_file) { fixture_file_upload('spec/fixtures/files/empty_file.txt', 'text/plain') }
  let(:locked_file) { fixture_file_upload('spec/fixtures/files/locked_pdf_password_is_test.pdf', 'application/pdf') }
  let(:malformed_file) { fixture_file_upload('spec/fixtures/files/malformed-pdf.pdf', 'application/pdf') }

  before do
    sign_in_as(user)
    allow(BenefitsIntake::Service).to receive(:new).and_return(benefits_intake)
    allow(benefits_intake).to receive(:valid_document?).and_return(true)
  end

  describe '#create' do
    it 'succeeds with a valid document' do
      expect(StatsD).to receive(:increment).with('api.claim_documents.attempt', tags: include('form_id:21P-527EZ'))
      expect(StatsD).to receive(:increment).with('api.claim_documents.success', tags: include('form_id:21P-527EZ'))
      post(:create, params: { 'form_id' => '21P-527EZ', 'file' => valid_file })
    end

    it 'succeeds with a locked pdf and password' do
      expect(StatsD).to receive(:increment).with('api.claim_documents.attempt', tags: include('form_id:21P-527EZ'))
      expect(StatsD).to receive(:increment).with('api.claim_documents.success', tags: include('form_id:21P-527EZ'))
      post(:create, params: { 'form_id' => '21P-527EZ', 'file' => locked_file, 'password' => 'test' })
    end

    it 'records input error with a locked pdf and incorrect password' do
      expect(StatsD).to receive(:increment).with('api.claim_documents.attempt', tags: include('form_id:21P-527EZ'))
      expect(StatsD).to receive(:increment).with('api.claim_documents.input_error', tags: include('form_id:21P-527EZ'))
      post(:create, params: { 'form_id' => '21P-527EZ', 'file' => locked_file, 'password' => 'password' })
    end

    it 'records input error with an empty document' do
      expect(StatsD).to receive(:increment).with('api.claim_documents.attempt', tags: include('form_id:21P-527EZ'))
      expect(StatsD).to receive(:increment).with('api.claim_documents.input_error', tags: include('form_id:21P-527EZ'))
      post(:create, params: { 'form_id' => '21P-527EZ', 'file' => empty_file })
    end

    it 'records input error with an malformed document' do
      expect(StatsD).to receive(:increment).with('api.claim_documents.attempt', tags: include('form_id:21P-527EZ'))
      expect(StatsD).to receive(:increment).with('api.claim_documents.input_error', tags: include('form_id:21P-527EZ'))
      post(:create, params: { 'form_id' => '21P-527EZ', 'file' => malformed_file })
    end

    it 'records failure for unexpected errors' do
      expect(StatsD).to receive(:increment).with('api.claim_documents.attempt', tags: include('form_id:21P-527EZ'))
      expect(StatsD).to receive(:increment).with('api.claim_documents.failure', tags: include('form_id:21P-527EZ'))
      # missing file param
      post(:create, params: { 'form_id' => '21P-527EZ' })
    end
  end
end
