# frozen_string_literal: true

require 'rails_helper'
require 'claim_letters/claim_letter_downloader'

describe ClaimStatusTool::ClaimLetterDownloader do
  let(:doc_id) { '{99DA7758-A10A-43F4-A056-C961C76A2DDF}' }
  let(:current_user) do
    create(:evss_user)
  end
  let(:allowed_doctypes) { %w[184] }

  before do
    @downloader = ClaimStatusTool::ClaimLetterDownloader.new(current_user, allowed_doctypes)
  end

  describe '#get_letters' do
    it 'retrieves letters in descending order according to received_at date' do
      letters = @downloader.get_letters

      expect(letters.first[:received_at]).to be >= letters.last[:received_at]
    end

    it 'retrieves letters matching only the allowed doc types' do
      letters = @downloader.get_letters
      doc_types = letters.pluck(:doc_type).uniq

      expect(doc_types).to match_array(allowed_doctypes)
    end
  end

  describe '#get_letter' do
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

  describe 'Board Of Appeals Letter functionality' do
    context 'BOA Letters enabled' do
      let(:allowed_doctypes) { %w[27 184] }

      before do
        @downloader = ClaimStatusTool::ClaimLetterDownloader.new(current_user, allowed_doctypes)
      end

      it 'only shows BOA letters older than 2 days' do
        letters = @downloader.get_letters
        boa_letters = letters.select { |l| l[:doc_type] == '27' }
        expect(boa_letters.length).to eq(1)
      end
    end

    context 'BOA Letters disabled' do
      let(:allowed_doctypes) { %w[184] }

      before do
        @downloader = ClaimStatusTool::ClaimLetterDownloader.new(current_user, allowed_doctypes)
      end

      it 'does not show BOA letters' do
        letters = @downloader.get_letters
        expect(letters.any? { |l| l[:doc_type] == '27' }).to be false
      end
    end
  end

  describe 'unifying letters display names in the api' do
    let(:allowed_doctypes) { %w[27 34 184 408 700 704 706 858 859 864 942 1605] }
    let(:type_description_map) do
      {
        '27' => 'Board decision',
        '34' => 'Request for specific evidence or information',
        '184' => 'Claim decision (or other notification, like Intent to File)',
        '408' => 'Notification: Exam with VHA has been scheduled',
        '700' => 'Request for specific evidence or information',
        '704' => 'List of evidence we may need ("5103 notice")',
        '706' => 'List of evidence we may need ("5103 notice")',
        '858' => 'List of evidence we may need ("5103 notice")',
        '859' => 'Request for specific evidence or information',
        '864' => 'Copy of request for medical records sent to a non-VA provider',
        '942' => 'Final notification: Request for specific evidence or information',
        '1605' => 'Copy of request for non-medical records sent to a non-VA organization'
      }
    end

    before do
      @downloader = ClaimStatusTool::ClaimLetterDownloader.new(current_user, allowed_doctypes)
    end

    it 'gives each letter a `display_description` field' do
      letters = @downloader.get_letters
      letters.each do |letter|
        expect(letter[:type_description]).to eq(type_description_map[letter[:doc_type]])
      end
    end
  end
end
