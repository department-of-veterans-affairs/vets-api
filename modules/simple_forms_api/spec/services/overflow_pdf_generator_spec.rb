# frozen_string_literal: true

require 'rails_helper'
require 'pdf/reader'

RSpec.describe SimpleFormsApi::OverflowPdfGenerator do
  let(:cutoff) { 3685 }

  def pdf_text(path)
    PDF::Reader.new(path).pages.map(&:text).join("\n")
  end

  before { @generated_paths = [] }

  after do
    @generated_paths.each { |p| FileUtils.rm_f(p) if p.present? && File.exist?(p) }
  end

  describe '#generate' do
    context 'when there is overflow text' do
      let(:data) do
        {
          'statement' => "#{'a' * 3686} overflow content",
          'full_name' => { 'first' => 'John', 'middle' => 'M', 'last' => 'Doe' },
          'id_number' => { 'ssn' => '123456789' }
        }
      end

      it 'returns a path to an existing PDF file' do
        path = described_class.new(data, cutoff:).generate
        @generated_paths << path
        expect(path).to be_a(String)
        expect(File.exist?(path)).to be(true)
      end

      it 'renders expected header, identity, remarks, and footer cutoff (robust to PDF text extraction spacing)' do
        path = described_class.new(data, cutoff:).generate
        @generated_paths << path
        content = pdf_text(path)

        aggregate_failures do
          expect(content).to match(/VA\s*Form\s*21-4138/i)

          expect(content).to match(/Name:\s*John\s*M\s*Doe/i)
          expect(content).to match(/SSN:\s*123-45-6789/)

          expect(content).to match(/Remarks.*continued/i)
          expect(content).to match(/overflow\s*content/i)
        end
      end
    end

    context 'when VA file number is present (preferred over SSN)' do
      let(:data) do
        {
          'statement' => ('b' * 3687),
          'full_name' => { 'first' => 'Jane', 'last' => 'Veteran' },
          'id_number' => { 'va_file_number' => '88888888', 'ssn' => '987654321' }
        }
      end

      it 'shows VA File Number and does not display SSN (handles collapsed spaces)' do
        path = described_class.new(data, cutoff:).generate
        @generated_paths << path
        content = pdf_text(path)

        aggregate_failures do
          expect(content).to match(/VA\s*File\s*Number:\s*88888888/i)
          expect(content).not_to match(/SSN:\s*987-65-4321/)
        end
      end
    end

    context 'when no name is provided' do
      let(:data) do
        {
          'statement' => ('c' * 3687), # ensure overflow
          'full_name' => {},
          'id_number' => { 'ssn' => '123456789' }
        }
      end

      it 'renders Name: Not provided (handles collapsed spaces)' do
        path = described_class.new(data, cutoff:).generate
        @generated_paths << path
        content = pdf_text(path)

        expect(content).to match(/Name:\s*Not\s*provided/i)
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
        path = described_class.new(data, cutoff:).generate
        expect(path).to be_nil
      end
    end
  end
end
