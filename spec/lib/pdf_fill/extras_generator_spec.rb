# frozen_string_literal: true
require 'spec_helper'
require 'pdf_fill/extras_generator'

describe PdfFill::ExtrasGenerator do
  subject do
    described_class.new
  end

  describe '#add_text' do
    it 'should add text to the variable' do
      subject.add_text('foo')
      expect(subject.instance_variable_get(:@text)).to eq("foo\n")
    end
  end

  describe '#generate' do
    it 'should generate the pdf' do
      subject.add_text('foo')
      file_path = subject.generate

      expect(
        FileUtils.compare_file(file_path, "spec/fixtures/pdf_fill/extras.pdf")
      ).to eq(true)

      File.delete(file_path)
    end
  end
end
