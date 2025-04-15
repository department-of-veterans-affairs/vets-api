# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/extras_generator'

describe PdfFill::ExtrasGenerator do
  subject { described_class.new }

  describe '#sort_generate_blocks' do
    let(:metadatas) do
      [
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
    end

    it 'sorts the blocks correctly' do
      subject.instance_variable_set(:@generate_blocks, metadatas.reverse.map do |metadata|
        {
          metadata:
        }
      end)

      subject.sort_generate_blocks.each_with_index do |generate_block, i|
        expect(generate_block[:metadata]).to eq(metadatas[i])
      end
    end
  end

  describe '#generate' do
    it 'works with unicode chars' do
      subject.add_text(
        'Ǽ',
        question_num: 1,
        question_suffix: 'A',
        question_text: 'foo',
        i: 1
      )
      File.delete(subject.generate)
    end

    it 'generates the pdf' do
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
      ).to be(true)

      File.delete(file_path)
    end
  end
end
