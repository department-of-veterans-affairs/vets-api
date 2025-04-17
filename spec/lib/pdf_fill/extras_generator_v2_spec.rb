# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/extras_generator_v2'

describe PdfFill::ExtrasGeneratorV2 do
  subject { described_class.new(sections:) }

  let(:sections) { nil }

  describe PdfFill::ExtrasGeneratorV2::Question do
    subject do
      question = described_class.new('First name', add_text_calls.first[1], table_width: 91)
      add_text_calls.each { |call| question.add_text(*call) }
      question
    end

    describe '#sorted_subquestions' do
      let(:add_text_calls) do
        [
          ['foo', { question_suffix: 'A', question_text: 'Name' }],
          ['bar', { question_suffix: 'B' }],
          ['baz', { question_text: 'Email' }]
        ]
      end

      context 'when not all subquestions have all metadata' do
        it 'sorts correctly by defaulting suffix and text to empty' do
          expect(subject.sorted_subquestions.pluck(:value)).to eq(%w[baz foo bar])
        end
      end
    end
  end

  describe '#populate_section_indices!' do
    let(:sections) do
      [
        {
          label: 'Section I',
          question_nums: (1..7).to_a
        },
        {
          label: 'Section II',
          question_nums: [8, 9]
        }
      ]
    end

    it 'populates section indices correctly' do
      questions = [1, 9, 42, 7].index_with do |question_num|
        described_class::Question.new(nil, { question_num: }, table_width: 91)
      end
      subject.instance_variable_set(:@questions, questions)
      subject.populate_section_indices!
      indices = subject.instance_variable_get(:@questions).values.map(&:section_index)
      expect(indices).to eq([0, 1, nil, 0])
    end
  end

  describe '#sort_generate_blocks' do
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

  describe '#add_page_numbers' do
    subject { described_class.new(start_page: 8) }

    let(:pdf) { instance_double(Prawn::Document, bounds: double('Bounds', right: 400, bottom: 0)) }

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

  describe '#set_header' do
    subject { described_class.new(form_name:, submit_date:) }

    let(:form_name) { 'TEST' }
    let(:submit_date) { nil }
    let(:pdf) do
      double(Prawn::Document, bounds: double('Bounds', width: 500, top: 700, left: 0, right: 500), markup: nil)
    end
    let(:header_font_size) { described_class::HEADER_FONT_SIZE }
    let(:subheader_font_size) { described_class::SUBHEADER_FONT_SIZE }

    before do
      allow(pdf).to receive(:repeat).and_yield
      allow(pdf).to receive(:bounding_box).and_yield
      allow(pdf).to receive(:markup)
      allow(pdf).to receive(:pad_top).and_yield
      allow(pdf).to receive(:stroke_horizontal_rule)
    end

    context 'when submit_date is not present' do
      it 'adds the header text correctly' do
        subject.set_header(pdf)
        expect(pdf).to have_received(:markup).with("<b>ATTACHMENT</b> to VA Form #{form_name}",
                                                   text: { align: :left, valign: :bottom, size: header_font_size })
        expect(pdf).to have_received(:markup).with('VA.gov Submission',
                                                   text: { align: :right, valign: :bottom, size: subheader_font_size })
        expect(pdf).to have_received(:stroke_horizontal_rule)
      end
    end

    context 'when submit_date is present' do
      let(:submit_date) { DateTime.new(2020, 12, 25, 14, 30, 0, '+0000') }

      it 'adds the header text correctly' do
        subject.set_header(pdf)
        expect(pdf).to have_received(:markup).with("<b>ATTACHMENT</b> to VA Form #{form_name}",
                                                   text: { align: :left, valign: :bottom, size: header_font_size })
        expect(pdf).to have_received(:markup).with('VA.gov Submission',
                                                   text: { align: :right, valign: :bottom, size: subheader_font_size })
        expect(pdf).to have_received(:stroke_horizontal_rule)
      end
    end
  end

  describe '#format_timestamp' do
    it 'returns nil for blank datetime' do
      expect(subject.send(:format_timestamp, nil)).to be_nil
      expect(subject.send(:format_timestamp, '')).to be_nil
    end

    it 'formats datetime correctly in UTC' do
      datetime = DateTime.new(2020, 12, 25, 14, 30, 0, '+0000')
      expect(subject.send(:format_timestamp, datetime)).to eq('14:30 UTC 2020-12-25')
    end

    it 'converts non-UTC times to UTC' do
      datetime = DateTime.new(2020, 12, 25, 9, 30, 0, '-0500') # EST time
      expect(subject.send(:format_timestamp, datetime)).to eq('14:30 UTC 2020-12-25')
    end
  end

  describe '#add_footer' do
    subject { described_class.new(submit_date:) }

    let(:pdf) { double('Prawn::Document', bounds: double('Bounds', bottom: 50, left: 0, width: 500)) }
    let(:footer_font_size) { described_class::FOOTER_FONT_SIZE }
    let(:submit_date) { DateTime.new(2020, 12, 25, 14, 30, 0, '+0000') }

    before do
      allow(pdf).to receive(:repeat).with(:all).and_yield
      allow(pdf).to receive(:bounding_box).and_yield
      allow(pdf).to receive(:markup)
    end

    context 'when submit_date is present' do
      it 'adds the footer text with timestamp and identity verification message' do
        subject.add_footer(pdf)
        expected_text = 'Signed electronically and submitted via VA.gov at 14:30 UTC 2020-12-25. ' \
                        'Signee signed with an identity-verified account.'
        expect(pdf).to have_received(:markup).with(
          expected_text, text: { align: :left, size: footer_font_size }
        )
      end
    end

    context 'when submit_date is not present' do
      let(:submit_date) { nil }

      it 'does not add footer' do
        subject.add_footer(pdf)
        expect(pdf).not_to have_received(:markup)
      end
    end
  end

  describe '#measure_content_heights' do
    let(:sections) do
      [
        {
          label: 'Section I',
          question_nums: [1]
        },
        {
          label: 'Section II',
          question_nums: [2]
        }
      ]
    end
    let(:question_block1) { instance_double(PdfFill::ExtrasGeneratorV2::Question, section_index: 0) }
    let(:question_block2) { instance_double(PdfFill::ExtrasGeneratorV2::Question, section_index: 1) }
    let(:list_block) { instance_double(PdfFill::ExtrasGeneratorV2::ListQuestion, section_index: 0) }
    let(:generate_blocks) { [question_block1, question_block2, list_block] }

    before do
      allow(question_block1).to receive(:is_a?).with(PdfFill::ExtrasGeneratorV2::ListQuestion).and_return(false)
      allow(question_block1).to receive(:measure_actual_height).and_return(100)
      allow(question_block2).to receive(:is_a?).with(PdfFill::ExtrasGeneratorV2::ListQuestion).and_return(false)
      allow(question_block2).to receive(:measure_actual_height).and_return(150)
      allow(list_block).to receive(:is_a?).with(PdfFill::ExtrasGeneratorV2::ListQuestion).and_return(true)
      allow(list_block).to receive(:measure_component_heights).and_return({ title: 30, items: [50, 60] })
    end

    it 'creates a hash with heights for each block' do
      heights = subject.measure_content_heights(generate_blocks)
      expect(heights).to be_a(Hash)
      expect(heights.compare_by_identity?).to be(true)
      expect(heights[:sections][0]).not_to be_nil
      expect(heights[:sections][1]).not_to be_nil
      expect(heights[question_block1]).to eq(100)
      expect(heights[question_block2]).to eq(150)
      expect(heights[list_block]).to eq({ title: 30, items: [50, 60] })
    end
  end

  describe '#handle_regular_question_page_break' do
    let(:pdf) { instance_double(Prawn::Document) }
    let(:question_block) { instance_double(PdfFill::ExtrasGeneratorV2::Question) }
    let(:block_heights) do
      heights = {}.compare_by_identity
      heights[question_block] = 200
      heights[:sections] = { 0 => 20 }
      heights
    end

    before do
      allow(pdf).to receive(:cursor).and_return(250)
      allow(pdf).to receive(:start_new_page)
    end

    context 'when content fits on the page' do
      it 'returns false without starting a new page' do
        result = subject.handle_regular_question_page_break(pdf, question_block, 0, block_heights)
        expect(result).to be(false)
        expect(pdf).not_to have_received(:start_new_page)
      end
    end

    context 'when content does not fit on the page' do
      before do
        allow(pdf).to receive(:cursor).and_return(200)
      end

      it 'starts a new page and returns true' do
        result = subject.handle_regular_question_page_break(pdf, question_block, 0, block_heights)
        expect(result).to be(true)
        expect(pdf).to have_received(:start_new_page)
      end
    end
  end

  describe '#handle_list_title_page_break' do
    let(:pdf) { instance_double(Prawn::Document) }
    let(:list_block) { instance_double(PdfFill::ExtrasGeneratorV2::ListQuestion) }
    let(:block_heights) do
      heights = {}.compare_by_identity
      heights[list_block] = { title: 30, items: [50, 60] }
      heights[:sections] = { 0 => 20 }
      heights
    end

    before do
      allow(pdf).to receive(:cursor).and_return(150)
      allow(pdf).to receive(:start_new_page)
    end

    context 'when title and first item fit on the page' do
      it 'returns false without starting a new page' do
        result = subject.handle_list_title_page_break(pdf, list_block, 0, block_heights)
        expect(result).to be(false)
        expect(pdf).not_to have_received(:start_new_page)
      end
    end

    context 'when title and first item do not fit on the page' do
      before do
        allow(pdf).to receive(:cursor).and_return(80)
      end

      it 'starts a new page and returns true' do
        result = subject.handle_list_title_page_break(pdf, list_block, 0, block_heights)
        expect(result).to be(true)
        expect(pdf).to have_received(:start_new_page)
      end
    end
  end

  describe '#render_list_items' do
    let(:pdf) { double('Prawn::Document', bounds: double('Bounds', bottom: 50)) }
    let(:list_block) { instance_double(PdfFill::ExtrasGeneratorV2::ListQuestion) }
    let(:item1) { instance_double(PdfFill::ExtrasGeneratorV2::Question) }
    let(:item2) { instance_double(PdfFill::ExtrasGeneratorV2::Question) }
    let(:block_heights) do
      heights = {}.compare_by_identity
      heights[list_block] = { items: [50, 100] }
      heights
    end

    before do
      allow(list_block).to receive(:items).and_return([item1, item2])
      allow(list_block).to receive(:render_item)
      allow(pdf).to receive(:cursor).and_return(75)
      allow(pdf).to receive(:start_new_page)
    end

    it 'renders each item and handles page breaks correctly' do
      subject.render_list_items(pdf, list_block, block_heights)

      expect(list_block).to have_received(:render_item).with(pdf, item1, 1)
      expect(list_block).to have_received(:render_item).with(pdf, item2, 2)
      expect(pdf).to have_received(:start_new_page).once
    end
  end

  describe '#sorted_subquestions_markup' do
    let(:metadata) do
      {
        question_suffix: 'A',
        question_label: 'Additional information',
        question_text: 'Request for a change in duty assignment',
        is_description: true,
        question_num: 10
      }
    end

    let(:question) do
      PdfFill::ExtrasGeneratorV2::Question.new(
        'Behavioral Change', metadata, table_width: 91
      )
    end

    it 'adds a description row when label is Additional information' do
      question.add_text('no response', metadata)
      rows = question.sorted_subquestions_markup

      expect(rows.first).to include('<b>Description:</b>')
      expect(rows.first).to include(metadata[:question_text])
      expect(rows.last).to include('no response')
    end
  end
end
