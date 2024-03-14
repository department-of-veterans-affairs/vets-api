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

  describe '#index when "cst_include_ddl_boa_letters" is enabled and "cst_include_ddl_5103_letters" is disabled' do
    before do
      Flipper.enable(:cst_include_ddl_boa_letters)
      Flipper.disable(:cst_include_ddl_5103_letters)
    end

    it 'lists correct documents' do
      get(:index)
      letters = JSON.parse(response.body)
      allowed_letters = letters.select { |d| %w[27 184].include?(d['doc_type']) }

      expect(allowed_letters.length).to eql(letters.length)
    end
  end

  describe '#index when "cst_include_ddl_5103_letters" is enabled and "cst_include_ddl_boa_letters" is disabled' do
    before do
      Flipper.enable(:cst_include_ddl_5103_letters)
      Flipper.disable(:cst_include_ddl_boa_letters)
    end

    it 'lists correct documents' do
      get(:index)
      letters = JSON.parse(response.body)
      allowed_letters = letters.select { |d| %w[704 706 858 184].include?(d['doc_type']) }

      expect(allowed_letters.length).to eql(letters.length)
    end
  end

  describe '#index when "cst_include_ddl_5103_letters" and "cst_include_ddl_boa_letters" feature flags are disabled' do
    before do
      Flipper.disable(:cst_include_ddl_5103_letters)
      Flipper.disable(:cst_include_ddl_boa_letters)
    end

    it 'lists correct documents' do
      get(:index)
      letters = JSON.parse(response.body)
      allowed_letters = letters.select { |d| d['doc_type'] == '184' }

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
      allow(Rails.logger).to receive(:info)
    end

    it 'logs metadata of document types to DataDog' do
      get(:index)
      expect(Rails.logger)
        .to have_received(:info)
        .with('DDL Document Types Metadata',
              { message_type: 'ddl.doctypes_metadata',
                document_type_metadata: [
                  { doc_type: '27',
                    type_description: 'Board Of Appeals Decision Letter' },
                  { doc_type: '858',
                    type_description: 'Custom 5103 Notice' },
                  { doc_type: '706',
                    type_description: '5103/DTA Letter' },
                  { doc_type: '184',
                    type_description: 'Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)' },
                  { doc_type: '184',
                    type_description: 'Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)' },
                  { doc_type: '184',
                    type_description: 'Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)' },
                  { doc_type: '704',
                    type_description: 'Standard 5103 Notice' },
                  { doc_type: '184',
                    type_description: 'Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)' },
                  { doc_type: '184',
                    type_description: 'Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)' }
                ] })
    end
  end
end
