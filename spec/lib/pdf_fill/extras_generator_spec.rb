# frozen_string_literal: true
require 'rails_helper'
require 'pdf_fill/extras_generator'

describe PdfFill::ExtrasGenerator do
  subject do
    described_class.new
  end

  describe '#sort_generate_blocks' do
    it 'should sort the blocks correctly' do
      metadatas = [
        {
          question_num: 1
        },
        {
          question_num: 2,
          question_suffix: 'A'
        },
        {
          question_num: 2,
          question_suffix: 'B'
        },
        {
          question_num: 3,
          question_suffix: 'A',
          i: 0
        },
        {
          question_num: 3,
          question_suffix: 'A',
          i: 1
        },
        {
          question_num: 3,
          question_suffix: 'A'
        },
        {
          question_num: 3,
          question_suffix: 'B'
        }
      ]

      subject.instance_variable_set(:@generate_blocks, metadatas.reverse.map do |metadata|
        {
          metadata: metadata
        }
      end)

      subject.sort_generate_blocks.each_with_index do |generate_block, i|
        expect(generate_block[:metadata]).to eq(metadatas[i])
      end
    end
  end

  describe '#generate' do
    it 'should work with unicode chars' do
      subject.add_text(
        'Ǽ',
        question_num: 1,
        question_suffix: 'A',
        question_text: 'foo',
        i: 1
      )
      File.delete(subject.generate)
    end

    it 'should generate the pdf' do
      subject.add_text(
        'bar',
        question_num: 1,
        question_suffix: 'A',
        question_text: 'foo',
        i: 1
      )
      file_path = subject.generate

      expect(
        FileUtils.compare_file(file_path, 'spec/fixtures/pdf_fill/extras.pdf')
      ).to eq(true)

      File.delete(file_path)
    end
  end
end
