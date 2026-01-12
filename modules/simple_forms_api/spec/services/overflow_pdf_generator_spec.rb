# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::OverflowPdfGenerator do
  let(:timestamp) { Time.zone.parse('2024-01-15 14:30:00 UTC') }

  after do
    # Cleanup generated PDFs
    Dir.glob(Rails.root.join('tmp', 'pdfs', '21-4138_overflow_*.pdf')).each do |file|
      File.delete(file) if File.exist?(file)
    end
  end

  describe '#generate' do
    context 'when there is overflow text' do
      let(:data) do
        {
          'statement' => 'a' * 3686 + 'overflow content',
          'full_name' => { 'first' => 'John', 'middle' => 'M', 'last' => 'Doe' },
          'id_number' => { 'ssn' => '123456789' }
        }
      end

      it 'generates a PDF file' do
        result = described_class.new(data, timestamp).generate
        expect(result).to be_a(String)
        expect(File.exist?(result)).to be true
      end

      it 'creates PDF in tmp/pdfs directory' do
        result = described_class.new(data, timestamp).generate
        expect(result).to include('tmp/pdfs')
        expect(result).to match(/21-4138_overflow_.*\.pdf/)
      end
    end

    context 'when there is no overflow text' do
      let(:data) do
        {
          'statement' => 'a' * 3685,
          'full_name' => { 'first' => 'John', 'last' => 'Doe' },
          'id_number' => { 'ssn' => '123456789' }
        }
      end

      it 'returns nil' do
        result = described_class.new(data, timestamp).generate
        expect(result).to be_nil
      end
    end
  end
end