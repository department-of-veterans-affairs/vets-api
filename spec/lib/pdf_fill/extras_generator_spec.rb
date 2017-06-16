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
end
