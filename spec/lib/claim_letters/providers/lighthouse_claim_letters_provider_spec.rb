# frozen_string_literal: true

require 'rails_helper'
require 'claim_letters/providers/claim_letters/lighthouse_claim_letters_provider'
require 'claim_letters/responses/claim_letters_response'
require 'claim_letters/utils/letter_transformer'
require 'support/claim_letters/claims_letters_provider'

RSpec.describe LighthouseClaimLettersProvider do
  let(:current_user) { build(:user, :loa3) }
  let(:provider) { described_class.new(current_user) }
  let(:mock_service) { instance_double(BenefitsDocuments::Service) }

  before do
    allow(BenefitsDocuments::Service).to receive(:new).with(current_user).and_return(mock_service)
  end

  it_behaves_like 'claim letters provider'

  describe '#get_letters' do
    let(:lighthouse_response_body) do
      {
        'data' => {
          'documents' => [
            {
              'docTypeId' => 184,
              'subject' => 'Test Subject',
              'documentUuid' => '12345678-ABCD-0123-cdef-124345679ABC',
              'originalFileName' => 'SupportingDocument.pdf',
              'documentTypeLabel' => 'VA 21-526 Veterans Application for Compensation or Pension',
              'trackedItemId' => 600_000_001,
              'uploadedDateTime' => '2016-02-04T17:51:56Z',
              'receivedAt' => '2016-02-04'
            }
          ]
        }
      }
    end

    let(:lighthouse_response) do
      instance_double(Faraday::Response, body: lighthouse_response_body, status: 200)
    end

    before do
      allow(mock_service).to receive(:claim_letters_search).and_return(lighthouse_response)
    end

    it 'retrieves and transforms claim letters from the Lighthouse API' do
      letters = provider.get_letters

      expect(letters.length).to eq(1)
      expect(letters.first).to be_a(ClaimLetters::Responses::ClaimLetterResponse)
      expect(letters.first.subject).to eq('Test Subject')
      expect(letters.first.document_id).to eq('12345678-ABCD-0123-cdef-124345679ABC')
    end

    it 'calls the service with correct parameters' do
      provider.get_letters

      expect(mock_service).to have_received(:claim_letters_search).with(
        doc_type_ids: kind_of(Array),
        file_number: nil,
        participant_id: current_user.participant_id
      )
    end
  end

  describe '#get_letter' do
    let(:pdf_content) { 'mock pdf file content' }
    let(:document_uuid) { '123-456-789' }
    let(:download_response) { double('response', content: pdf_content, body: pdf_content) }

    context 'when letter metadata is found' do
      let(:search_response_body) do
        {
          'data' => {
            'documents' => [
              {
                'docTypeId' => 184,
                'subject' => 'Test Subject',
                'documentUuid' => document_uuid,
                'receivedAt' => '2023-06-15',
                'uploadedDateTime' => '2023-06-15T10:30:00Z'
              },
              {
                'docTypeId' => 184,
                'subject' => 'Another Document',
                'documentUuid' => 'different-uuid',
                'receivedAt' => '2023-05-01'
              }
            ]
          }
        }
      end

      let(:search_response) do
        instance_double(Faraday::Response, body: search_response_body, status: 200)
      end

      before do
        allow(mock_service).to receive_messages(claim_letters_search: search_response,
                                                claim_letter_download: download_response)
        allow(ClaimLetters::Utils::LetterTransformer).to receive(:filename_with_date)
          .and_call_original
      end

      it 'downloads the letter using metadata for filename' do
        yielded_data = nil
        yielded_filename = nil

        provider.get_letter(document_uuid) do |data, mime_type, disposition, filename|
          yielded_data = data
          yielded_filename = filename
          expect(mime_type).to eq('application/pdf')
          expect(disposition).to eq('attachment')
        end

        expect(yielded_data).to eq(pdf_content)

        # Verify that filename_with_date was called with the receivedAt date
        expected_date = Time.zone.parse('2023-06-15')
        expect(ClaimLetters::Utils::LetterTransformer).to have_received(:filename_with_date)
          .with(expected_date)
      end

      it 'calls services in the correct order' do
        provider.get_letter(document_uuid) { |*| }

        # First it should search for metadata
        expect(mock_service).to have_received(:claim_letters_search).ordered

        # Then it should download the document
        expect(mock_service).to have_received(:claim_letter_download).ordered.with(
          document_uuid:,
          file_number: nil,
          participant_id: current_user.participant_id
        )
      end
    end

    context 'when letter metadata is not found' do
      let(:search_response_body) do
        {
          'data' => {
            'documents' => [
              {
                'docTypeId' => 184,
                'documentUuid' => 'different-uuid',
                'receivedAt' => '2023-05-01'
              }
            ]
          }
        }
      end

      let(:search_response) do
        instance_double(Faraday::Response, body: search_response_body, status: 200)
      end

      before do
        allow(mock_service).to receive(:claim_letters_search).and_return(search_response)
        # Stub claim_letter_download even though we don't expect it to be called
        allow(mock_service).to receive(:claim_letter_download)
        allow(Rails.logger).to receive(:error)
      end

      it 'raises RecordNotFound error' do
        expect do
          provider.get_letter(document_uuid) { |*| }
        end.to raise_error(Common::Exceptions::RecordNotFound)
      end

      it 'logs an error' do
        expect do
          provider.get_letter(document_uuid) { |*| }
        end.to raise_error(Common::Exceptions::RecordNotFound)

        expect(Rails.logger).to have_received(:error)
          .with("No metadata found for document_uuid: #{document_uuid}")
      end

      it 'does not attempt to download the letter' do
        expect do
          provider.get_letter(document_uuid) { |*| }
        end.to raise_error(Common::Exceptions::RecordNotFound)

        expect(mock_service).not_to have_received(:claim_letter_download)
      end
    end

    context 'when letter metadata has nil receivedAt' do
      let(:search_response_body) do
        {
          'data' => {
            'documents' => [
              {
                'docTypeId' => 184,
                'documentUuid' => document_uuid,
                'receivedAt' => nil,
                'uploadedDateTime' => '2023-06-15T10:30:00Z'
              }
            ]
          }
        }
      end

      let(:search_response) do
        instance_double(Faraday::Response, body: search_response_body, status: 200)
      end

      before do
        allow(mock_service).to receive_messages(claim_letters_search: search_response,
                                                claim_letter_download: download_response)
        allow(ClaimLetters::Utils::LetterTransformer).to receive(:filename_with_date)
          .and_return('fallback_filename.pdf')
        allow(DateTime).to receive(:now).and_return(DateTime.new(2023, 12, 1, 10, 0, 0))
      end

      it 'falls back to DateTime.now for filename' do
        provider.get_letter(document_uuid) do |_data, _mime_type, _disposition, filename|
          expect(filename).to eq('fallback_filename.pdf')
        end

        # Verify that filename_with_date was called with DateTime.now
        expect(ClaimLetters::Utils::LetterTransformer).to have_received(:filename_with_date)
          .with(DateTime.new(2023, 12, 1, 10, 0, 0))
      end
    end

    context 'when search response has empty documents array' do
      let(:search_response_body) do
        {
          'data' => {
            'documents' => []
          }
        }
      end

      let(:search_response) do
        instance_double(Faraday::Response, body: search_response_body, status: 200)
      end

      before do
        allow(mock_service).to receive(:claim_letters_search).and_return(search_response)
        allow(Rails.logger).to receive(:error)
      end

      it 'raises RecordNotFound error' do
        expect do
          provider.get_letter(document_uuid) { |*| }
        end.to raise_error(Common::Exceptions::RecordNotFound)
      end
    end

    context 'when search response has malformed data structure' do
      let(:search_response_body) do
        {
          'data' => nil
        }
      end

      let(:search_response) do
        instance_double(Faraday::Response, body: search_response_body, status: 200)
      end

      before do
        allow(mock_service).to receive(:claim_letters_search).and_return(search_response)
        allow(Rails.logger).to receive(:error)
      end

      it 'handles nil data gracefully' do
        expect do
          provider.get_letter(document_uuid) { |*| }
        end.to raise_error(Common::Exceptions::RecordNotFound)
      end
    end

    context 'when response data is missing documents key' do
      let(:lighthouse_response_body) do
        {
          'data' => {
            # No 'documents' key at all
            'some_other_field' => 'value'
          }
        }
      end

      let(:lighthouse_response) do
        instance_double(Faraday::Response, body: lighthouse_response_body, status: 200)
      end

      before do
        allow(mock_service).to receive(:claim_letters_search).and_return(lighthouse_response)
      end

      it 'returns an empty array without raising an error' do
        letters = provider.get_letters

        expect(letters).to eq([])
        expect(letters).to be_an(Array)
      end

      it 'still calls the service with correct parameters' do
        provider.get_letters

        expect(mock_service).to have_received(:claim_letters_search).with(
          doc_type_ids: kind_of(Array),
          file_number: nil,
          participant_id: current_user.participant_id
        )
      end
    end
  end

  describe '#fetch_letter_metadata' do
    let(:document_uuid) { '123-456-789' }

    context 'when testing the private method directly' do
      let(:search_response_body) do
        {
          'data' => {
            'documents' => [
              {
                'documentUuid' => document_uuid,
                'receivedAt' => '2023-06-15'
              },
              {
                'documentUuid' => 'other-uuid',
                'receivedAt' => '2023-05-01'
              }
            ]
          }
        }
      end

      let(:search_response) do
        instance_double(Faraday::Response, body: search_response_body, status: 200)
      end

      before do
        allow(mock_service).to receive(:claim_letters_search).and_return(search_response)
      end

      it 'returns the correct document metadata' do
        metadata = provider.send(:fetch_letter_metadata, document_uuid)

        expect(metadata).to eq({
                                 'documentUuid' => document_uuid,
                                 'receivedAt' => '2023-06-15'
                               })
      end

      it 'returns nil when document not found' do
        metadata = provider.send(:fetch_letter_metadata, 'non-existent-uuid')

        expect(metadata).to be_nil
      end
    end
  end

  describe 'caching behavior' do
    let(:document_uuid) { '123-456-789' }
    let(:search_response_body) do
      {
        'data' => {
          'documents' => [
            {
              'docTypeId' => 184,
              'documentUuid' => document_uuid,
              'receivedAt' => '2023-06-15'
            }
          ]
        }
      }
    end
    let(:search_response) do
      instance_double(Faraday::Response, body: search_response_body, status: 200)
    end
    let(:download_response) { double('response', body: 'pdf content') }

    before do
      allow(mock_service).to receive_messages(claim_letters_search: search_response,
                                              claim_letter_download: download_response)
      allow(ClaimLetters::Utils::LetterTransformer).to receive(:filename_with_date).and_return('test.pdf')
    end

    context 'when get_letters is called before get_letter' do
      it 'uses cached metadata and only makes one search call' do
        # First call get_letters which should cache the metadata
        provider.get_letters

        # Then call get_letter
        provider.get_letter(document_uuid) { |*| }

        # Should only call claim_letters_search once due to caching
        expect(mock_service).to have_received(:claim_letters_search).once
      end
    end

    context 'when get_letter is called without prior get_letters call' do
      it 'fetches metadata on demand' do
        # Call get_letter directly without calling get_letters first
        provider.get_letter(document_uuid) { |*| }

        # Should call claim_letters_search to fetch metadata
        expect(mock_service).to have_received(:claim_letters_search).once
      end
    end

    context 'when multiple get_letter calls are made' do
      let(:second_document_uuid) { '987-654-321' }
      let(:search_response_body) do
        {
          'data' => {
            'documents' => [
              {
                'docTypeId' => 184,
                'documentUuid' => document_uuid,
                'receivedAt' => '2023-06-15'
              },
              {
                'docTypeId' => 184,
                'documentUuid' => second_document_uuid,
                'receivedAt' => '2023-06-20'
              }
            ]
          }
        }
      end

      it 'reuses cached metadata for subsequent calls' do
        # First call should fetch and cache metadata
        provider.get_letter(document_uuid) { |*| }

        # Second call should use cached metadata
        provider.get_letter(second_document_uuid) { |*| }

        # Should only call claim_letters_search once due to caching
        expect(mock_service).to have_received(:claim_letters_search).once

        # But should call download twice (once for each letter)
        expect(mock_service).to have_received(:claim_letter_download).twice
      end
    end

    context 'when testing cache invalidation' do
      it 'allows fresh instance to fetch new data' do
        # First provider instance
        provider1 = described_class.new(current_user)
        provider1.get_letter(document_uuid) { |*| }

        # Create new provider instance (simulating new request)
        provider2 = described_class.new(current_user)
        provider2.get_letter(document_uuid) { |*| }

        # Each instance should make its own search call
        expect(mock_service).to have_received(:claim_letters_search).twice
      end
    end
  end

  describe 'edge case handling' do
    let(:document_uuid) { '123-456-789' }

    context 'when Lighthouse returns unexpected data structure' do
      let(:search_response_body) do
        {
          'data' => {
            'documents' => [
              {
                # Missing documentUuid field
                'docTypeId' => 184,
                'receivedAt' => '2023-06-15'
              }
            ]
          }
        }
      end
      let(:search_response) do
        instance_double(Faraday::Response, body: search_response_body, status: 200)
      end

      before do
        allow(mock_service).to receive(:claim_letters_search).and_return(search_response)
        allow(Rails.logger).to receive(:error)
      end

      it 'handles missing documentUuid gracefully' do
        expect do
          provider.get_letter(document_uuid) { |*| }
        end.to raise_error(Common::Exceptions::RecordNotFound)
      end
    end

    context 'when date parsing returns nil' do
      let(:search_response_body) do
        {
          'data' => {
            'documents' => [
              {
                'docTypeId' => 184,
                'documentUuid' => document_uuid,
                'receivedAt' => 'invalid-date-format'
              }
            ]
          }
        }
      end
      let(:search_response) do
        instance_double(Faraday::Response, body: search_response_body, status: 200)
      end
      let(:download_response) { double('response', body: 'pdf content') }

      before do
        allow(mock_service).to receive_messages(claim_letters_search: search_response,
                                                claim_letter_download: download_response)
        allow(ClaimLetters::Utils::LetterTransformer).to receive(:filename_with_date)
          .and_return('fallback.pdf')
        allow(DateTime).to receive(:now).and_return(DateTime.new(2023, 12, 1))
        # Time.zone.parse returns nil for invalid dates
        allow(Time.zone).to receive(:parse).with('invalid-date-format').and_return(nil)
      end

      it 'falls back to DateTime.now when date parsing returns nil' do
        provider.get_letter(document_uuid) do |_data, _mime_type, _disposition, filename|
          expect(filename).to eq('fallback.pdf')
        end

        # Verify that filename_with_date was called with DateTime.now due to nil parse result
        expect(ClaimLetters::Utils::LetterTransformer).to have_received(:filename_with_date)
          .with(DateTime.new(2023, 12, 1))
      end
    end
  end

  describe 'integration with allowed doctypes filtering' do
    let(:provider_with_custom_doctypes) { described_class.new(current_user, %w[184 27]) }
    let(:document_uuid) { '123-456-789' }

    it 'respects allowed doctypes when fetching metadata' do
      search_response = instance_double(Faraday::Response, body: { 'data' => { 'documents' => [] } })
      allow(mock_service).to receive(:claim_letters_search).and_return(search_response)

      expect do
        provider_with_custom_doctypes.get_letter(document_uuid) { |*| }
      end.to raise_error(Common::Exceptions::RecordNotFound)

      expect(mock_service).to have_received(:claim_letters_search).with(
        doc_type_ids: %w[184 27],
        file_number: nil,
        participant_id: current_user.participant_id
      )
    end
  end
end
