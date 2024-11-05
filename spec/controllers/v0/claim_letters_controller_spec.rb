# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::ClaimLettersController, type: :controller do
  let(:user) { build(:user, :loa3) }
  let(:document_id) { '{27832B64-2D88-4DEE-9F6F-DF80E4CAAA87}' }
  let(:filename) { 'ClaimLetter-2022-9-22.pdf' }
  let(:list_letters_res) { get_fixture('claim_letter/claim_letter_list') }

  before do
    sign_in_as(user)
  end

  describe '#index' do
    it 'lists document id and letter details for claim letters' do
      get(:index)
      letters = JSON.parse(response.body)
      expected_important_keys = %w[document_id doc_type received_at]

      expect(letters.length).to be > 0
      # We can reference the keys of the first letters since
      # they _should_ all have the same keys.
      expect(letters.first.keys).to include(*expected_important_keys)
    end
  end

  describe '#index when "cst_include_ddl_boa_letters" is enabled
  and "cst_include_ddl_5103_letters" and "cst_include_ddl_sqd_letters" are disabled' do
    before do
      Flipper.enable(:cst_include_ddl_boa_letters)
      Flipper.disable(:cst_include_ddl_5103_letters)
      Flipper.disable(:cst_include_ddl_sqd_letters)
    end

    it 'lists correct documents' do
      get(:index)
      letters = JSON.parse(response.body)
      allowed_letters = letters.select { |d| %w[27 184].include?(d['doc_type']) }

      expect(allowed_letters.length).to eql(letters.length)
    end
  end

  describe '#index when "cst_include_ddl_5103_letters" is enabled
  and "cst_include_ddl_boa_letters" and "cst_include_ddl_sqd_letters" are disabled' do
    before do
      Flipper.enable(:cst_include_ddl_5103_letters)
      Flipper.disable(:cst_include_ddl_boa_letters)
      Flipper.disable(:cst_include_ddl_sqd_letters)
    end

    it 'lists correct documents' do
      get(:index)
      letters = JSON.parse(response.body)
      allowed_letters = letters.select { |d| %w[704 706 858 184].include?(d['doc_type']) }

      expect(allowed_letters.length).to eql(letters.length)
    end
  end

  describe '#index when "cst_include_ddl_sqd_letters" is enabled
  and "cst_include_ddl_boa_letters" and "cst_include_ddl_5103_letters" are disabled' do
    before do
      Flipper.disable(:cst_include_ddl_5103_letters)
      Flipper.disable(:cst_include_ddl_boa_letters)
      Flipper.enable(:cst_include_ddl_sqd_letters)
    end

    it 'lists correct documents' do
      get(:index)
      letters = JSON.parse(response.body)
      allowed_letters = letters.select { |d| %w[184 34 408 700 859 864 942 1605].include?(d['doc_type']) }

      expect(allowed_letters.length).to eql(letters.length)
    end
  end

  describe '#index when "cst_include_ddl_5103_letters", "cst_include_ddl_boa_letters",
  and "cst_include_ddl_sqd_letters" feature flags are disabled' do
    before do
      Flipper.disable(:cst_include_ddl_5103_letters)
      Flipper.disable(:cst_include_ddl_boa_letters)
      Flipper.disable(:cst_include_ddl_sqd_letters)
    end

    it 'lists correct documents' do
      get(:index)
      letters = JSON.parse(response.body)
      allowed_letters = letters.select { |d| d['doc_type'] == '184' }

      expect(allowed_letters.length).to eql(letters.length)
    end
  end

  describe '#index when "cst_include_ddl_5103_letters", "cst_include_ddl_boa_letters",
  and "cst_include_ddl_sqd_letters" feature flags are all enabled' do
    before do
      Flipper.enable(:cst_include_ddl_5103_letters)
      Flipper.enable(:cst_include_ddl_boa_letters)
      Flipper.enable(:cst_include_ddl_sqd_letters)
    end

    it 'lists correct documents' do
      all_allowed_doctypes = %w[27 34 184 408 700 704 706 858 859 864 942 1605]
      get(:index)
      letters = JSON.parse(response.body)
      allowed_letters = letters.select { |d| all_allowed_doctypes.include?(d['doc_type']) }

      expect(allowed_letters.length).to eql(letters.length)
    end
  end

  describe '#show' do
    it 'responds with a pdf with a dated filename' do
      get(:show, params: { document_id: })

      expect(response.header['Content-Type']).to eq('application/pdf')
      expect(response.header['Content-Disposition']).to include("filename=\"#{filename}\"")
    end

    it 'returns a 404 with a not found message if document id does not exist' do
      get(:show, params: { document_id: '{0}' })
      err = JSON.parse(response.body)['errors'].first

      expect(err['status']).to eql('404')
      expect(err['title'].downcase).to include('not found')
    end

    it 'has a dated filename' do
      get(:show, params: { document_id: })

      expect(response.header['Content-Disposition']).to include("filename=\"#{filename}\"")
    end
  end

  context 'DDL Logging' do
    before do
      Flipper.enable(:cst_include_ddl_5103_letters)
      Flipper.enable(:cst_include_ddl_boa_letters)
      Flipper.enable(:cst_include_ddl_sqd_letters)
      allow(Rails.logger).to receive(:info)
    end

    it 'logs metadata of document types to DataDog' do
      get(:index)
      expect(Rails.logger)
        .to have_received(:info)
        .with('DDL Document Types Metadata',
              message_type: 'ddl.doctypes_metadata',
              document_type_metadata: contain_exactly(
                { doc_type: '27',
                  type_description: 'Board decision' },
                { doc_type: '864',
                  type_description: 'Copy of request for medical records sent to a non-VA provider' },
                { doc_type: '859',
                  type_description: 'Request for specific evidence or information' },
                { doc_type: '700',
                  type_description: 'Request for specific evidence or information' },
                { doc_type: '408',
                  type_description: 'Notification: Exam with VHA has been scheduled' },
                { doc_type: '34',
                  type_description: 'Request for specific evidence or information' },
                { doc_type: '858',
                  type_description: 'List of evidence we may need ("5103 notice")' },
                { doc_type: '1605',
                  type_description: 'Copy of request for non-medical records sent to a non-VA organization' },
                { doc_type: '942',
                  type_description: 'Final notification: Request for specific evidence or information' },
                { doc_type: '706',
                  type_description: 'List of evidence we may need ("5103 notice")' },
                { doc_type: '184',
                  type_description: 'Claim decision (or other notification, like Intent to File)' },
                { doc_type: '184',
                  type_description: 'Claim decision (or other notification, like Intent to File)' },
                { doc_type: '184',
                  type_description: 'Claim decision (or other notification, like Intent to File)' },
                { doc_type: '704',
                  type_description: 'List of evidence we may need ("5103 notice")' },
                { doc_type: '184',
                  type_description: 'Claim decision (or other notification, like Intent to File)' },
                { doc_type: '184',
                  type_description: 'Claim decision (or other notification, like Intent to File)' }
              ))
    end
  end
end
