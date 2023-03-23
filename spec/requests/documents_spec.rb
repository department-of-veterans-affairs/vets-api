# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documents management', type: :request do
  let(:file) { fixture_file_upload('doctors-note.pdf', 'application/pdf') }
  let(:tracked_item_id) { 33 }
  let(:document_type) { 'L023' }
  let!(:claim) do
    FactoryBot.create(:evss_claim, id: 1, evss_id: 189_625,
                                   user_uuid: user.uuid, data: {})
  end
  let(:user) { FactoryBot.create(:user, :loa3) }

  before { sign_in_as(user) }

  it 'uploads a file' do
    params = { file:, tracked_item_id:, document_type: }
    expect do
      post('/v0/evss_claims/189625/documents', params:)
    end.to change(EVSS::DocumentUpload.jobs, :size).by(1)
    expect(response.status).to eq(202)
    expect(JSON.parse(response.body)['job_id']).to eq(EVSS::DocumentUpload.jobs.first['jid'])
  end

  it 'rejects files with invalid document_types' do
    params = { file:, tracked_item_id:, document_type: 'invalid type' }
    post('/v0/evss_claims/189625/documents', params:)
    expect(response.status).to eq(422)
    expect(JSON.parse(response.body)['errors'].first['title']).to eq(
      I18n.t('errors.messages.uploads.document_type_unknown')
    )
  end

  it 'normalizes requests with a null tracked_item_id' do
    params = { file:, tracked_item_id: 'null', document_type: }
    post('/v0/evss_claims/189625/documents', params:)
    args = EVSS::DocumentUpload.jobs.first['args'][2]
    expect(response.status).to eq(202)
    expect(JSON.parse(response.body)['job_id']).to eq(EVSS::DocumentUpload.jobs.first['jid'])
    expect(args.key?('tracked_item_id')).to eq(true)
    expect(args['tracked_item_id']).to be_nil
  end

  context 'with unaccepted file_type' do
    let(:file) { fixture_file_upload('invalid_idme_cert.crt', 'application/x-x509-ca-cert') }

    it 'rejects files with invalid document_types' do
      params = { file:, tracked_item_id:, document_type: }
      post('/v0/evss_claims/189625/documents', params:)
      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)['errors'].first['title']).to eq('Unprocessable Entity')
    end
  end

  context 'with locked PDF and no provided password' do
    let(:locked_file) { fixture_file_upload('locked_pdf_password_is_test.pdf', 'application/pdf') }

    it 'rejects locked PDFs if no password is provided' do
      params = { file: locked_file, tracked_item_id:, document_type: }
      post('/v0/evss_claims/189625/documents', params:)
      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)['errors'].first['title']).to eq(I18n.t('errors.messages.uploads.pdf.locked'))
    end

    it 'accepts locked PDFs with the correct password' do
      params = { file: locked_file, tracked_item_id:, document_type:, password: 'test' }
      post('/v0/evss_claims/189625/documents', params:)
      expect(response.status).to eq(202)
      expect(JSON.parse(response.body)['job_id']).to eq(EVSS::DocumentUpload.jobs.first['jid'])
    end

    it 'rejects locked PDFs with the incocorrect password' do
      params = { file: locked_file, tracked_item_id:, document_type:, password: 'bad' }
      post('/v0/evss_claims/189625/documents', params:)
      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)['errors'].first['title']).to eq(
        I18n.t('errors.messages.uploads.pdf.incorrect_password')
      )
    end
  end

  context 'with a false file extension' do
    let(:tempfile) do
      f = Tempfile.new(['not-a', '.pdf'])
      f.write('I am not a PDF')
      f.rewind
      fixture_file_upload(f.path, 'application/pdf')
    end

    it 'rejects a file that is not really a PDF' do
      params = { file: tempfile, tracked_item_id:, document_type: }
      post('/v0/evss_claims/189625/documents', params:)
      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)['errors'].first['title']).to eq(I18n.t('errors.messages.uploads.malformed_pdf'))
    end
  end

  context 'with no body' do
    let(:file) { fixture_file_upload('empty_file.txt', 'text/plain') }

    it 'rejects a text file with no body' do
      params = { file:, tracked_item_id:, document_type: }
      post('/v0/evss_claims/189625/documents', params:)
      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)['errors'].first['detail']).to eq(
        I18n.t('errors.messages.min_size_error', min_size: '1 Byte')
      )
    end
  end

  context 'with an emoji in text' do
    let(:tempfile) do
      f = Tempfile.new(['test', '.txt'])
      f.write("I \u2661 Unicode!")
      f.rewind
      fixture_file_upload(f.path, 'text/plain')
    end

    it 'rejects a text file containing untranslatable characters' do
      params = { file: tempfile, tracked_item_id:, document_type: }
      post('/v0/evss_claims/189625/documents', params:)
      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)['errors'].first['title']).to eq(I18n.t('errors.messages.uploads.ascii_encoded'))
    end
  end

  context 'with UTF-16 ASCII text' do
    let(:tempfile) do
      f = Tempfile.new(['test', '.txt'], encoding: 'utf-16be')
      f.write('I love nulls')
      f.rewind
      fixture_file_upload(f.path, 'text/plain')
    end

    it 'accepts a text file containing translatable characters' do
      params = { file: tempfile, tracked_item_id:, document_type: }
      post('/v0/evss_claims/189625/documents', params:)
      expect(response.status).to eq(202)
      expect(JSON.parse(response.body)['job_id']).to eq(EVSS::DocumentUpload.jobs.first['jid'])
    end
  end

  context 'with a PDF pretending to be text' do
    let(:tempfile) do
      f = Tempfile.new(['test', '.txt'], encoding: 'utf-16be')
      pdf = File.open(::Rails.root.join(*'/spec/fixtures/files/doctors-note.pdf'.split('/')).to_s, 'rb')
      FileUtils.copy_stream(pdf, f)
      pdf.close
      f.rewind
      fixture_file_upload(f.path, 'text/plain')
    end

    it 'rejects a text file containing binary data' do
      params = { file: tempfile, tracked_item_id:, document_type: }
      post('/v0/evss_claims/189625/documents', params:)
      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)['errors'].first['title']).to eq(I18n.t('errors.messages.uploads.ascii_encoded'))
    end
  end
end
