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

      expect(letters.length).to eq(1)  # Fixed: use .length instead of have(1).item
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
    # Mock both content and body methods that the implementation uses
    let(:download_response) { double('response', content: pdf_content, body: pdf_content) }

    before do
      allow(mock_service).to receive(:claim_letter_download).and_return(download_response)
      allow(ClaimLetters::Utils::LetterTransformer).to receive(:filename_with_date)
                                                         .and_return('test_filename.pdf')
    end

    it 'downloads and yields the PDF content with correct metadata' do
      yielded_data = nil
      yielded_filename = nil

      provider.get_letter(document_uuid) do |data, mime_type, disposition, filename|
        yielded_data = data
        yielded_filename = filename
        expect(mime_type).to eq('application/pdf')
        expect(disposition).to eq('attachment')
      end

      expect(yielded_data).to eq(pdf_content)
      expect(yielded_filename).to eq('test_filename.pdf')
    end

    it 'calls the service with correct parameters' do
      provider.get_letter(document_uuid) { |*| }

      expect(mock_service).to have_received(:claim_letter_download).with(
        document_uuid: document_uuid,
        file_number: nil,
        participant_id: current_user.participant_id
      )
    end
  end
end