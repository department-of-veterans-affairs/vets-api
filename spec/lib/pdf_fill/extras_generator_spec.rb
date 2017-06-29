# frozen_string_literal: true
require 'spec_helper'
require 'pdf_fill/extras_generator'

describe PdfFill::ExtrasGenerator do
  subject do
    described_class.new
  end

  describe '#generate' do
    it 'should generate the pdf' do
      subject.add_text('foo', 'bar')
      subject.add_text('foo1', 'bar1')
      file_path = subject.generate

      expect(
        FileUtils.compare_file(file_path, 'spec/fixtures/pdf_fill/extras.pdf')
      ).to eq(true)

      File.delete(file_path)
    end
  end
end
