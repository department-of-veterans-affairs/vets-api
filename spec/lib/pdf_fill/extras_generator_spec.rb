# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/extras_generator'

describe PdfFill::ExtrasGenerator do
  subject { described_class.new(sections:) }

  let(:sections) { nil }

  describe '#populate_section_indices!' do
    let(:sections) do
      [
        {
          label: 'Section I',
          top_level_keys: %w[veteranFullName vaFileNumber veteranDateOfBirth]
        },
        {
          label: 'Section II',
          top_level_keys: ['events']
        }
      ]
    end

    it 'populates section indices correctly' do
      blocks = %w[veteranFullName events evidence vaFileNumber].map do |top_level_key|
        { metadata: { top_level_key: } }
      end
      subject.instance_variable_set(:@generate_blocks, blocks)
      subject.populate_section_indices!
      indices = subject.instance_variable_get(:@generate_blocks).map { |block| block[:metadata][:section_index] }
      expect(indices).to eq([0, 1, nil, 0])
    end
  end

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

    context 'when section metadata is provided' do
      let(:metadatas) do
        [
          { section_index: 0, question_num: 2, question_suffix: 'A', question_text: 'First Name' },
          { section_index: 0, question_num: 2, question_suffix: 'B', question_text: 'Last Name' },
          { section_index: 0, question_num: 3, question_text: 'Email Address' },
          { section_index: 1, question_num: 1, question_text: 'Remarks' },
          { section_index: 1, question_num: 4, question_text: 'Additional Remarks' }
        ]
      end

      it 'sorts the blocks correctly, even if question numbers are jumbled' do
        subject.instance_variable_set(:@generate_blocks, metadatas.reverse.map { |metadata| { metadata: } })

        subject.sort_generate_blocks.each_with_index do |generate_block, i|
          expect(generate_block[:metadata]).to eq(metadatas[i])
        end
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

  describe '#add_page_numbers' do
    subject { described_class.new(start_page: 8, extras_redesign: true) }

    let(:pdf) { instance_double(Prawn::Document, bounds: double('Bounds', right: 400)) }

    it 'adds page numbers starting at @start_page' do
      expect(pdf).to receive(:number_pages).with(
        'Page <page>',
        start_count_at: 8,
        at: [400 - 50, 0],
        align: :right,
        size: 9
      )

      subject.add_page_numbers(pdf)
    end
  end
end
