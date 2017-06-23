# frozen_string_literal: true
require 'rails_helper'
require 'evss/document_upload'

RSpec.describe 'Documents management', type: :request do
  let(:file) do
    fixture_file_upload(
      "#{::Rails.root}/spec/fixtures/files/doctors-note.pdf",
      'application/pdf'
    )
  end
  let(:tracked_item_id) { 33 }
  let(:document_type) { 'L023' }
  let!(:claim) do
    FactoryGirl.create(:evss_claim, id: 1, evss_id: 189_625,
                                    user_uuid: user.uuid, data: {})
  end
  let(:user) { FactoryGirl.create(:loa3_user) }
  let(:session) { Session.create(uuid: user.uuid) }

  it 'should upload a file' do
    params = { file: file, tracked_item_id: tracked_item_id, document_type: document_type }
    expect do
      post '/v0/evss_claims/189625/documents', params, 'Authorization' => "Token token=#{session.token}"
    end.to change(Workflow::Runner.jobs, :size).by(1)
    expect(response.status).to eq(202)
    expect(JSON.parse(response.body)['job_id']).to eq(Workflow::Runner.jobs.first['jid'])
  end

  it 'should reject files with invalid document_types' do
    params = { file: file, tracked_item_id: tracked_item_id, document_type: 'invalid type' }
    post '/v0/evss_claims/189625/documents', params, 'Authorization' => "Token token=#{session.token}"
    expect(response.status).to eq(422)
    expect(JSON.parse(response.body)['errors'].first['title']).to eq('Must use a known document type')
  end

  it 'should normalize requests with a null tracked_item_id' do
    params = { file: file, tracked_item_id: 'null', document_type: document_type }
    post '/v0/evss_claims/189625/documents', params, 'Authorization' => "Token token=#{session.token}"
    args = Workflow::Runner.jobs.first['args'][1]['options']['document']
    expect(response.status).to eq(202)
    expect(JSON.parse(response.body)['job_id']).to eq(Workflow::Runner.jobs.first['jid'])
    expect(args.key?('tracked_item_id')).to eq(true)
    expect(args['tracked_item_id']).to be_nil
  end

  context 'with locked PDF' do
    let(:locked_file) do
      fixture_file_upload(
        "#{::Rails.root}/spec/fixtures/files/locked-pdf.pdf",
        'application/pdf'
      )
    end

    it 'should reject locked PDFs' do
      params = { file: locked_file, tracked_item_id: tracked_item_id, document_type: document_type }
      post '/v0/evss_claims/189625/documents', params, 'Authorization' => "Token token=#{session.token}"
      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)['errors'].first['title']).to eq(I18n.t('uploads.pdf.locked'))
    end
  end

  context 'with a false file extension' do
    let(:tempfile) do
      f = Tempfile.new(['not-a', '.pdf'])
      f.write('I am not a PDF')
      f.rewind
      fixture_file_upload(f.path, 'application/pdf')
    end

    it 'should accept a file that is not really a PDF' do
      params = { file: tempfile, tracked_item_id: tracked_item_id, document_type: document_type }
      post '/v0/evss_claims/189625/documents', params, 'Authorization' => "Token token=#{session.token}"
      expect(response.status).to eq(202)
      args = Workflow::Runner.jobs.first['args'][1]['internal']['file']
      mime_type = JSON.parse(args)['metadata']['mime_type']
      expect(mime_type).to eq('text/plain')
    end
  end

  context 'with an emoji in text' do
    let(:tempfile) do
      f = Tempfile.new(['test', '.txt'])
      f.write("I \u2661 Unicode!")
      f.rewind
      fixture_file_upload(f.path, 'text/plain')
    end

    it 'should reject a text file containing untranslatable characters' do
      params = { file: tempfile, tracked_item_id: tracked_item_id, document_type: document_type }
      post '/v0/evss_claims/189625/documents', params, 'Authorization' => "Token token=#{session.token}"
      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)['errors'].first['title']).to eq(
        'Cannot read file encoding. Text files must be ASCII encoded.'
      )
    end
  end

  context 'with UTF-16 ASCII text' do
    let(:tempfile) do
      f = Tempfile.new(['test', '.txt'], encoding: 'utf-16be')
      f.write('I love nulls')
      f.rewind
      fixture_file_upload(f.path, 'text/plain')
    end

    it 'should accept a text file containing translatable characters' do
      params = { file: tempfile, tracked_item_id: tracked_item_id, document_type: document_type }
      post '/v0/evss_claims/189625/documents', params, 'Authorization' => "Token token=#{session.token}"
      expect(response.status).to eq(202)
      expect(JSON.parse(response.body)['job_id']).to eq(Workflow::Runner.jobs.first['jid'])
    end
  end

  context 'with a PDF pretending to be text' do
    let(:tempfile) do
      f = Tempfile.new(['test', '.txt'], encoding: 'utf-16be')
      pdf = File.open("#{::Rails.root}/spec/fixtures/files/doctors-note.pdf", 'rb')
      FileUtils.copy_stream(pdf, f)
      pdf.close
      f.rewind
      fixture_file_upload(f.path, 'text/plain')
    end

    it 'should reject a text file containing binary data' do
      params = { file: tempfile, tracked_item_id: tracked_item_id, document_type: document_type }
      post '/v0/evss_claims/189625/documents', params, 'Authorization' => "Token token=#{session.token}"
      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)['errors'].first['title']).to eq(
        'Cannot read file encoding. Text files must be ASCII encoded.'
      )
    end
  end
end
