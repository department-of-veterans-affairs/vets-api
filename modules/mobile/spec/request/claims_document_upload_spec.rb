# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'
require 'lighthouse/benefits_documents/service'

RSpec.describe 'claims document upload', type: :request do
  include JsonSchemaMatchers

  let(:user) { FactoryBot.build(:iam_user) }
  let(:file) { fixture_file_upload('doctors-note.pdf', 'application/pdf') }
  let(:claim_id) { 33 }
  let(:tracked_item_ids) { [33] }
  let(:document_type) { 'L023' }
  let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  before do
    iam_sign_in user
    token = 'abcdefghijklmnop'
    allow_any_instance_of(BGS::People::Response).to receive(:file_number).and_return('12345')
    allow_any_instance_of(BenefitsDocuments::Configuration).to receive(:access_token).and_return(token)
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('24811694708759028')
    Flipper.enable(:mobile_lighthouse_document_upload, user)
    FileUtils.rm_rf(Rails.root.join('tmp', 'uploads', 'cache', '*'))
  end

  after do
    Flipper.disable(:mobile_lighthouse_document_upload, user)
  end

  it 'uploads a file' do
    params = { file:, claim_id:, tracked_item_ids:, documentType: document_type }
    expect do
      post '/mobile/v0/claim/600117255/documents', params:, headers: iam_headers
    end.to change(Lighthouse::DocumentUpload.jobs, :size).by(1)

    expect(response.status).to eq(202)
    expect(response.parsed_body.dig('data', 'jobId')).to eq(Lighthouse::DocumentUpload.jobs.first['jid'])
  end

  it 'uploads multiple jpeg files' do
    skip 'Test is flakey'
    files = [Base64.encode64(File.read('spec/fixtures/files/doctors-note.jpg')),
             Base64.encode64(File.read('spec/fixtures/files/marriage-cert.jpg'))]
    params = { files:, claim_id:, tracked_item_ids:, documentType: document_type }
    expect do
      post '/mobile/v0/claim/600117255/documents/multi-image', params: params.to_json,
                                                               headers: iam_headers(json_body_headers)
    end.to change(Lighthouse::DocumentUpload.jobs, :size).by(1)
    expect(response.status).to eq(202)
    expect(response.parsed_body.dig('data', 'jobId')).to eq(Lighthouse::DocumentUpload.jobs.first['jid'])
    expect(Dir.empty?(Rails.root.join('tmp', 'uploads', 'cache'))).to eq(true)
  end

  it 'uploads multiple gif files' do
    skip 'Test is flakey'
    files = [Base64.encode64(File.read('spec/fixtures/files/doctors-note.gif')),
             Base64.encode64(File.read('spec/fixtures/files/marriage-cert.gif'))]
    params = { files:, claim_id:, documentType: document_type, tracked_item_ids: }
    expect do
      post '/mobile/v0/claim/600117255/documents/multi-image', params: params.to_json,
                                                               headers: iam_headers(json_body_headers)
    end.to change(Lighthouse::DocumentUpload.jobs, :size).by(1)
    expect(response.status).to eq(202)
    expect(response.parsed_body.dig('data', 'jobId')).to eq(Lighthouse::DocumentUpload.jobs.first['jid'])
    expect(Dir.empty?(Rails.root.join('tmp', 'uploads', 'cache'))).to eq(true)
  end

  it 'uploads multiple mixed img files' do
    skip 'Test is flakey'
    files = [Base64.encode64(File.read('spec/fixtures/files/doctors-note.jpg')),
             Base64.encode64(File.read('spec/fixtures/files/marriage-cert.gif'))]
    params = { files:, claim_id:, documentType: document_type, tracked_item_ids: }
    expect do
      post '/mobile/v0/claim/600117255/documents/multi-image', params: params.to_json,
                                                               headers: iam_headers(json_body_headers)
    end.to change(Lighthouse::DocumentUpload.jobs, :size).by(1)
    expect(response.status).to eq(202)
    expect(response.parsed_body.dig('data', 'jobId')).to eq(Lighthouse::DocumentUpload.jobs.first['jid'])
    expect(Dir.empty?(Rails.root.join('tmp', 'uploads', 'cache'))).to eq(true)
  end

  it 'rejects files with invalid document_types' do
    params = { file:, claim_id:, documentType: 'invalid type', tracked_item_ids: }
    post '/mobile/v0/claim/600117255/documents', params:, headers: iam_headers
    expect(response.status).to eq(422)
    expect(
      response.parsed_body['errors'].first['title']
    ).to eq(I18n.t('errors.messages.uploads.document_type_unknown'))
  end

  it 'normalizes requests with a null tracked_item_id' do
    params = { file:, claim_id:, tracked_item_ids: 'null', documentType: document_type }
    post '/mobile/v0/claim/600117255/documents', params:, headers: iam_headers
    args = Lighthouse::DocumentUpload.jobs.first['args'][1]
    expect(response.status).to eq(202)
    expect(response.parsed_body.dig('data', 'jobId')).to eq(Lighthouse::DocumentUpload.jobs.first['jid'])
    expect(args.key?('tracked_item_id')).to eq(true)
    expect(args['tracked_item_id']).to be_nil
  end

  context 'with a user that has multiple file numbers' do
    before do
      allow_any_instance_of(BGS::People::Response).to receive(:file_number).and_return(%w[12345 56789])
    end

    it 'uploads a file' do
      params = { file:, claim_id:, tracked_item_ids:, documentType: document_type }
      expect do
        post '/mobile/v0/claim/600117255/documents', params:, headers: iam_headers
      end.to change(Lighthouse::DocumentUpload.jobs, :size).by(1)

      expect(response.status).to eq(202)
      expect(response.parsed_body.dig('data', 'jobId')).to eq(Lighthouse::DocumentUpload.jobs.first['jid'])
    end
  end

  context 'with unaccepted file_type' do
    let(:file) { fixture_file_upload('invalid_idme_cert.crt', 'application/x-x509-ca-cert') }

    it 'rejects files with invalid document_types' do
      params = { file:, claim_id:, documentType: document_type, tracked_item_ids: }
      post '/mobile/v0/claim/600117255/documents', params:, headers: iam_headers
      expect(response.status).to eq(500)
      expect(response.parsed_body['errors'].first['title']).to eq('Internal server error')
      expect(response.parsed_body['errors'].first['meta']['exception']).to match(/can.t upload/)
    end
  end

  context 'with locked PDF and no provided password' do
    let(:locked_file) { fixture_file_upload('locked_pdf_password_is_test.pdf', 'application/pdf') }

    it 'rejects locked PDFs if no password is provided' do
      params = { file: locked_file, claim_id:, documentType: document_type, tracked_item_ids: }
      post '/mobile/v0/claim/600117255/documents', params:, headers: iam_headers
      expect(response.status).to eq(422)
      expect(response.parsed_body['errors'].first['title']).to eq(I18n.t('errors.messages.uploads.pdf.locked'))
    end

    it 'accepts locked PDFs with the correct password' do
      params = { file: locked_file, claim_id:, documentType: document_type, password: 'test', tracked_item_ids: }
      post '/mobile/v0/claim/600117255/documents', params:, headers: iam_headers
      expect(response.status).to eq(202)
      expect(response.parsed_body.dig('data', 'jobId')).to eq(Lighthouse::DocumentUpload.jobs.first['jid'])
    end

    it 'rejects locked PDFs with the incorrect password' do
      params = { file: locked_file, claim_id:, documentType: document_type, password: 'bad', tracked_item_ids: }
      post '/mobile/v0/claim/600117255/documents', params:, headers: iam_headers
      expect(response.status).to eq(422)
      expect(
        response.parsed_body['errors'].first['title']
      ).to eq(I18n.t('errors.messages.uploads.pdf.incorrect_password'))
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
      params = { file: tempfile, claim_id:, documentType: document_type, tracked_item_ids: }
      post '/mobile/v0/claim/600117255/documents', params:, headers: iam_headers
      expect(response.status).to eq(422)
      expect(
        response.parsed_body['errors'].first['title']
      ).to eq(I18n.t('errors.messages.uploads.malformed_pdf'))
    end
  end

  context 'with no body' do
    let(:file) { fixture_file_upload('empty_file.txt', 'text/plain') }

    it 'rejects a text file with no body' do
      params = { file:, claim_id:, documentType: document_type, tracked_item_ids: }
      post '/mobile/v0/claim/600117255/documents', params:, headers: iam_headers
      expect(response.status).to eq(500)
      expect(response.parsed_body['errors'].first['meta']['exception']).to match(/1 Byte/)
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
      params = { file: tempfile, claim_id:, documentType: document_type, tracked_item_ids: }
      post '/mobile/v0/claim/600117255/documents', params:, headers: iam_headers
      expect(response.status).to eq(422)
      expect(
        response.parsed_body['errors'].first['title']
      ).to eq(I18n.t('errors.messages.uploads.ascii_encoded'))
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
      params = { file: tempfile, claim_id:, documentType: document_type, tracked_item_ids: }
      post '/mobile/v0/claim/600117255/documents', params:, headers: iam_headers
      expect(response.status).to eq(202)
      expect(response.parsed_body.dig('data', 'jobId')).to eq(Lighthouse::DocumentUpload.jobs.first['jid'])
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
      params = { file: tempfile, claim_id:, document_type:, tracked_item_ids: }
      post '/mobile/v0/claim/600117255/documents', params:, headers: iam_headers
      expect(response.status).to eq(422)
      expect(
        response.parsed_body['errors'].first['title']
      ).to eq(I18n.t('errors.messages.uploads.ascii_encoded'))
    end
  end
end
