# frozen_string_literal: true

require 'rails_helper'
require 'claim_letters/claim_letter_downloader'

describe ClaimStatusTool::ClaimLetterDownloader do
  let(:doc_id) { '{99DA7758-A10A-43F4-A056-C961C76A2DDF}' }
  let(:current_user) do
    create(:evss_user)
  end

  describe '#get_letters' do
    before do
      @downloader = ClaimStatusTool::ClaimLetterDownloader.new(current_user)
    end

    it 'retrieves letters in descending order according to received_at date' do
      letters = @downloader.get_letters

      expect(letters.first[:received_at]).to be >= letters.last[:received_at]
    end

    it 'retrieves letters matching only the allowed doc types' do
      letters = @downloader.get_letters
      doc_types = letters.pluck(:doc_type).uniq

      expect(doc_types).to match_array(@downloader.allowed_doctypes)
    end
  end

  describe '#get_letter' do
    before do
      @downloader = ClaimStatusTool::ClaimLetterDownloader.new(current_user)
    end

    it 'retrieves a single letter based on document id' do
      @downloader.get_letter(doc_id) do |data, mime_type, _disposition, _filename|
        expect(data).not_to be_nil
        expect(mime_type).to be('application/pdf')
      end
    end

    it 'names a letter with a dashed version of the received_at date' do
      letters = @downloader.get_letters
      expected_letter = letters.find { |l| l[:document_id] == doc_id }
      received_at = expected_letter[:received_at]

      @downloader.get_letter(doc_id) do |data, _mime_type, _disposition, filename|
        expect(data).not_to be_nil
        expect(filename).to include(received_at.year.to_s)
        expect(filename).to include(received_at.month.to_s)
        expect(filename).to include(received_at.day.to_s)
      end
    end

    it 'raises a RecordNotFound exception when it cannot find a document' do
      expect { @downloader.get_letter('{0}') }.to raise_error(Common::Exceptions::RecordNotFound)
    end
  end
end
