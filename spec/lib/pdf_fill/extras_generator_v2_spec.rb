# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/extras_generator_v2'

describe PdfFill::ExtrasGeneratorV2 do
  subject { described_class.new(sections:) }

  let(:sections) { nil }

  describe '#populate_section_indices!' do
    let(:sections) do
      [
        {
          label: 'Section I',
          question_nums: (1..7).to_a,
          top_level_keys: %w[veteranFullName vaFileNumber veteranDateOfBirth]
        },
        {
          label: 'Section II',
          question_nums: [8, 9],
          top_level_keys: ['events']
        }
      ]
    end

    it 'populates section indices correctly' do
      questions = [1, 9, 42, 7].index_with { |_| { subquestions: [], overflow: true } }
      subject.instance_variable_set(:@questions, questions)
      subject.populate_section_indices!
      indices = subject.instance_variable_get(:@questions).map { |_, question| question[:section_index] }
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
end
