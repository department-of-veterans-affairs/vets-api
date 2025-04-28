# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/extras_generator_v2'

describe PdfFill::ExtrasGeneratorV2 do
  subject { described_class.new(sections:) }

  let(:sections) { nil }

  describe PdfFill::ExtrasGeneratorV2::Question do
    subject do
      question = described_class.new('First name', add_text_calls.first[1])
      add_text_calls.each { |call| question.add_text(*call) }
      question
    end

    describe '#format_value' do
      it 'applies formatting based on format options' do
        question = described_class.new('Test', { question_num: 1 })

        # Test normal value
        expect(question.format_value('Hello', {})).to eq('Hello')

        # Test newlines converted to <br/>
        expect(question.format_value("Hello\nWorld", {})).to eq('Hello<br/>World')

        # Test 'no response' italicized
        expect(question.format_value('no response', {})).to eq('<i>no response</i>')

        # Test bold value
        expect(question.format_value('Hello', { bold_value: true })).to eq('<b>Hello</b>')

        # Test combination of newlines and bold
        expect(question.format_value("Hello\nWorld", { bold_value: true })).to eq('<b>Hello<br/>World</b>')
      end
    end

    describe '#format_label' do
      it 'applies bold formatting when specified' do
        question = described_class.new('Test', { question_num: 1 })

        # Test normal label
        expect(question.format_label('Name', {})).to eq('Name')

        # Test bold label
        expect(question.format_label('Name', { bold_label: true })).to eq('<b>Name</b>')
      end
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

    describe '#sorted_subquestions_markup' do
      context 'when the question is a checklist group' do
        let(:add_text_calls) do
          [
            [1, { question_label: 'Item 1', question_type: 'checklist_group' }],
            [0, { question_label: 'None' }],
            ['Miscellaneous details', { question_label: 'Other', question_type: 'checklist_group' }]
          ]
        end

        it 'renders correctly' do
          expect(subject.sorted_subquestions_markup).to eq(
            [
              '<tr><td><ul><li>Item 1</li></ul></td></tr>',
              '',
              '<tr><td><ul><li>Other: Miscellaneous details</li></ul></td></tr>'
            ]
          )
        end
      end

      context 'when there is only one subquestion' do
        let(:add_text_calls) do
          [
            ["foo\nbar", { question_suffix: 'A', question_text: 'Name' }]
          ]
        end

        it 'renders correctly' do
          expected_style = "width:#{PdfFill::ExtrasGeneratorV2::FREE_TEXT_QUESTION_WIDTH}"
          expect(subject.sorted_subquestions_markup).to eq(
            "<tr><td style='#{expected_style}'>foo<br/>bar</td><td></td></tr>"
          )
        end

        context 'with format options' do
          let(:add_text_calls) do
            [
              ["foo\nbar",
               { question_suffix: 'A', question_text: 'Name',
                 format_options: { bold_value: true, question_width: 300 } }]
            ]
          end

          it 'applies format options correctly' do
            expect(subject.sorted_subquestions_markup).to eq(
              "<tr><td style='width:300'><b>foo<br/>bar</b></td><td></td></tr>"
            )
          end
        end
      end

      context 'when there is more than one subquestion' do
        let(:add_text_calls) do
          [
            ["foo\nbar", { question_suffix: 'A', question_text: 'Name' }],
            ['bar', { question_suffix: 'B', question_text: 'Email' }]
          ]
        end

        it 'renders correctly' do
          expect(subject.sorted_subquestions_markup).to eq(
            [
              "<tr><td style='width:91'>Name:</td><td>foo<br/>bar</td></tr>",
              "<tr><td style='width:91'>Email:</td><td>bar</td></tr>"
            ]
          )
        end

        context 'with format options' do
          let(:add_text_calls) do
            [
              ["foo\nbar",
               { question_suffix: 'A', question_text: 'Name', format_options: { bold_label: true, label_width: 120 } }],
              ['bar', { question_suffix: 'B', question_text: 'Email', format_options: { bold_value: true } }]
            ]
          end

          it 'applies format options correctly to each subquestion' do
            expect(subject.sorted_subquestions_markup).to eq(
              [
                "<tr><td style='width:120'><b>Name</b>:</td><td>foo<br/>bar</td></tr>",
                "<tr><td style='width:91'>Email:</td><td><b>bar</b></td></tr>"
              ]
            )
          end
        end
      end
    end
  end

  describe PdfFill::ExtrasGeneratorV2::FreeTextQuestion do
    subject do
      question = described_class.new('Additional Remarks', add_text_calls.first[1])
      add_text_calls.each { |call| question.add_text(*call) }
      question
    end

    describe '#sorted_subquestions_markup' do
      let(:add_text_calls) do
        [
          ["foo\nbar", { question_suffix: 'A', question_text: 'Name', question_type: 'free_text' }],
          ['bar', { question_suffix: 'B', question_text: 'Email', question_type: 'free_text' }]
        ]
      end

      it 'renders correctly' do
        expected_style = "width:#{PdfFill::ExtrasGeneratorV2::FREE_TEXT_QUESTION_WIDTH}"
        expect(subject.sorted_subquestions_markup).to eq(
          [
            "<tr><td style='#{expected_style}'><p>foo</p><p>bar</p></td><td></td></tr>",
            "<tr><td style='#{expected_style}'><p>bar</p></td><td></td></tr>"
          ]
        )
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
        described_class::Question.new(nil, { question_num: })
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
      allow(list_block).to receive(:measure_actual_height).and_return({ title: 30, items: [50, 60] })
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
      allow(item1).to receive(:should_render?).and_return(true)
      allow(item2).to receive(:should_render?).and_return(true)
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

  describe 'CheckedDescriptionQuestion' do
    subject { described_class::CheckedDescriptionQuestion.new(question_text, metadata) }

    let(:question_text) { 'Test Question' }
    let(:pdf_double) { double('PDF', markup: nil) }
    let(:metadata) { { question_num: 1 } }

    describe '#initialize' do
      it 'initializes with default values' do
        expect(subject.description).to be_nil
        expect(subject.additional_info).to be_nil
        expect(subject.send(:should_render?)).to be false
      end
    end

    describe '#add_text' do
      context 'when adding Description' do
        it 'sets the description' do
          subject.add_text('Test Description', { question_text: 'Description' })
          expect(subject.description[:value]).to eq('Test Description')
          expect(subject.description[:format_options]).to eq({})
        end
      end

      context 'when adding Additional Information' do
        it 'sets the additional_info' do
          subject.add_text('More Info', { question_text: 'Additional Information' })
          expect(subject.additional_info[:value]).to eq('More Info')
          expect(subject.additional_info[:format_options]).to eq({})
        end
      end

      context 'when setting Checked status' do
        it 'sets checked to true when value is "true"' do
          subject.add_text('true', { question_text: 'Checked' })
          expect(subject.send(:should_render?)).to be true
        end

        it 'sets checked to false when value is not "true"' do
          subject.add_text('false', { question_text: 'Checked' })
          expect(subject.send(:should_render?)).to be false
        end
      end

      context 'when using question_label instead of question_text' do
        it 'sets the description using question_label' do
          subject.add_text('Test Description', { question_label: 'Description' })
          expect(subject.description[:value]).to eq('Test Description')
          expect(subject.description[:format_options]).to eq({})
        end
      end

      it 'sets overflow from metadata' do
        subject.add_text('Test', { overflow: false })
        expect(subject.instance_variable_get(:@overflow)).to be false
      end

      it 'defaults overflow to true when not specified' do
        subject.add_text('Test', {})
        expect(subject.instance_variable_get(:@overflow)).to be true
      end
    end

    describe '#render' do
      before do
        allow(pdf_double).to receive(:markup)
      end

      context 'when not checked' do
        it 'returns 0 without rendering' do
          expect(subject.render(pdf_double)).to eq(0)
          expect(pdf_double).not_to have_received(:markup)
        end
      end

      context 'when checked' do
        before do
          subject.add_text('true', { question_text: 'Checked' })
          subject.add_text('Test Description', { question_text: 'Description' })
        end

        it 'renders the header when not in list format' do
          subject.render(pdf_double)
          expect(pdf_double).to have_received(:markup).with('<h3>1. Test Question</h3>')
        end

        it 'does not render the header in list format' do
          subject.render(pdf_double, list_format: true)
          expect(pdf_double).not_to have_received(:markup).with('<h3>1. Test Question</h3>')
        end

        context 'with additional info' do
          before do
            subject.add_text('More Details', { question_text: 'Additional Information' })
          end

          it 'renders the table with description and additional info' do
            expected_markup = [
              '<table>',
              "<tr><td style='width:91'>Description:</td><td>Test Description</td></tr>",
              "<tr><td style='width:91'>Additional Information:</td><td>More Details</td></tr>",
              '</table>'
            ].join

            subject.render(pdf_double)
            expect(pdf_double).to have_received(:markup).with(expected_markup, text: { margin_bottom: 10 })
          end

          it 'renders with format options when specified' do
            subject.add_text('Test Description', {
                               question_text: 'Description',
                               format_options: { bold_label: true, bold_value: true, label_width: 120 }
                             })
            subject.add_text('More Details', {
                               question_text: 'Additional Information',
                               format_options: { bold_label: true, label_width: 120 }
                             })

            expected_markup = [
              '<table>',
              "<tr><td style='width:120'><b>Description:</b></td><td><b>Test Description</b></td></tr>",
              "<tr><td style='width:120'><b>Additional Information:</b></td><td>More Details</td></tr>",
              '</table>'
            ].join

            subject.render(pdf_double)
            expect(pdf_double).to have_received(:markup).with(expected_markup, text: { margin_bottom: 10 })
          end
        end

        context 'without additional info' do
          it 'renders the table with no response for additional info' do
            expected_markup = [
              '<table>',
              "<tr><td style='width:91'>Description:</td><td>Test Description</td></tr>",
              "<tr><td style='width:91'>Additional Information:</td><td><i>no response</i></td></tr>",
              '</table>'
            ].join

            subject.render(pdf_double)
            expect(pdf_double).to have_received(:markup).with(expected_markup, text: { margin_bottom: 10 })
          end
        end
      end
    end

    describe '#format_row' do
      it 'formats row with default styling' do
        row = subject.format_row('Name', 'John Doe', {})
        expect(row).to eq("<tr><td style='width:91'>Name:</td><td>John Doe</td></tr>")
      end

      it 'formats row with custom label width' do
        row = subject.format_row('Name', 'John Doe', { label_width: 150 })
        expect(row).to eq("<tr><td style='width:150'>Name:</td><td>John Doe</td></tr>")
      end

      it 'formats row with bold label' do
        row = subject.format_row('Name', 'John Doe', { bold_label: true })
        expect(row).to eq("<tr><td style='width:91'><b>Name:</b></td><td>John Doe</td></tr>")
      end

      it 'formats row with bold value' do
        row = subject.format_row('Name', 'John Doe', { bold_value: true })
        expect(row).to eq("<tr><td style='width:91'>Name:</td><td><b>John Doe</b></td></tr>")
      end

      it 'formats empty value as "no response" in italics' do
        row = subject.format_row('Name', '', {})
        expect(row).to eq("<tr><td style='width:91'>Name:</td><td><i>no response</i></td></tr>")

        row = subject.format_row('Name', nil, {})
        expect(row).to eq("<tr><td style='width:91'>Name:</td><td><i>no response</i></td></tr>")
      end

      it 'combines multiple format options' do
        row = subject.format_row('Name', 'John Doe', { bold_label: true, bold_value: true, label_width: 120 })
        expect(row).to eq("<tr><td style='width:120'><b>Name:</b></td><td><b>John Doe</b></td></tr>")
      end
    end
  end

  describe PdfFill::ExtrasGeneratorV2::ListQuestion do
    subject do
      question = described_class.new('List Question', metadata)
      question
    end

    let(:metadata) do
      {
        question_num: 9,
        item_label: 'Item',
        format_options: { bold_item_label: true, label_width: 120 }
      }
    end

    let(:pdf) { double('PDF') }

    before do
      allow(pdf).to receive(:markup)
    end

    describe '#render_item_label' do
      it 'renders item label with bold formatting when specified' do
        subject.render_item_label(pdf, 1)

        expect(pdf).to have_received(:markup).with(
          '<table><tr><th><b><i>Item 1</i></b></th></tr></table>',
          {
            table: {
              cell: {
                borders: [:bottom],
                border_width: 1,
                padding: [5, 0, 3.5, 0]
              }
            },
            text: { margin_bottom: -2 }
          }
        )
      end

      it 'uses regular italic formatting when bold_item_label is false' do
        # Create a new question with bold_item_label: false
        question = described_class.new('List Question', {
                                         question_num: 9,
                                         item_label: 'Item',
                                         format_options: { bold_item_label: false }
                                       })

        question.render_item_label(pdf, 1)

        expect(pdf).to have_received(:markup).with(
          '<table><tr><th><i>Item 1</i></th></tr></table>',
          {
            table: {
              cell: {
                borders: [:bottom],
                border_width: 1,
                padding: [5, 0, 3.5, 0]
              }
            },
            text: { margin_bottom: -2 }
          }
        )
      end
    end

    describe '#initialize' do
      it 'captures format_options from metadata' do
        expect(subject.instance_variable_get(:@format_options)).to eq(
          { bold_item_label: true, label_width: 120 }
        )
      end

      it 'defaults format_options to empty hash if not provided' do
        question = described_class.new('List Question', { question_num: 9, item_label: 'Item' })
        expect(question.instance_variable_get(:@format_options)).to eq({})
      end
    end

    describe '#add_text' do
      let(:item_metadata) do
        {
          i: 0,
          question_text: 'Description',
          format_options: { bold_value: true }
        }
      end

      it 'passes format_options to created items' do
        subject.add_text('Test Value', item_metadata)

        # The item should receive the format_options from the metadata
        item = subject.items.first
        added_value = item.instance_variable_get(:@subquestions).first

        expect(added_value[:metadata][:format_options]).to eq({ bold_value: true })
      end
    end
  end
end
