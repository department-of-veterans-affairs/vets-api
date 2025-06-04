# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/hash_converter'

describe PdfFill::HashConverter do
  let(:converter) do
    described_class.new('%m/%d/%Y', extras_generator)
  end
  let(:extras_generator) { instance_double(PdfFill::ExtrasGenerator) }
  let(:placeholder_text) { 'special placeholder text' }

  before { allow(extras_generator).to receive(:placeholder_text).and_return(placeholder_text) }

  def verify_extras_text(text, metadata)
    metadata[:overflow] = true unless metadata.key?(:overflow)
    metadata[:item_label] = nil unless metadata.key?(:item_label)
    metadata[:question_type] = nil unless metadata.key?(:question_type)
    metadata[:format_options] = {} unless metadata.key?(:format_options)
    expect(extras_generator).to receive(:add_text).with(text, metadata).once
  end

  describe '#set_value' do
    def verify_hash(hash)
      expect(converter.instance_variable_get(:@pdftk_form)).to eq(
        hash
      )
    end

    def call_set_value(*args)
      final_args = ['bar'] + args
      converter.set_value(*final_args)
    end

    def call_set_custom_value(value, *args)
      final_args = [value] + args
      converter.set_value(*final_args)
    end

    context 'with a dollar value' do
      [
        { value: '$100', expected: '$100.00' },
        { value: '1,000,000', expected: '$1,000,000.00' },
        { value: '1,000,000.01', expected: '$1,000,000.01' },
        { value: '0', expected: '$0.00' },
        { value: '42', expected: '$42.00' },
        { value: '123.45', expected: '$123.45' },
        { value: 1000, expected: '$1,000.00' },
        { value: 10_004.10, expected: '$10,004.10' },
        { value: -10_004.00, expected: '-$10,004.00' }
      ].each do |test_case|
        it "formats #{test_case[:value]} as #{test_case[:expected]}" do
          verify_extras_text(test_case[:expected], question_num: 1, question_text: 'foo', i: nil)

          call_set_custom_value(
            test_case[:value],
            {
              key: :foo,
              dollar: true,
              limit: 0,
              question_num: 1,
              question_text: 'foo'
            },
            nil
          )
        end
      end
    end

    context "with a value that's over limit" do
      it 'adds text to the extras page' do
        verify_extras_text('bar', question_num: 1, question_text: 'foo', i: nil)

        call_set_value(
          {
            key: :foo,
            limit: 2,
            question_num: 1,
            question_text: 'foo'
          },
          nil
        )

        verify_hash(foo: placeholder_text)
      end

      it 'formats date' do
        verify_extras_text('02/15/1995', question_num: 1, question_text: 'foo', i: nil)

        call_set_custom_value(
          '1995-2-15',
          {
            limit: 2,
            key: 'foo',
            format: 'date',
            question_num: 1,
            question_text: 'foo'
          },
          nil
        )

        verify_hash('foo' => placeholder_text)
      end

      it 'does not format string with date' do
        verify_extras_text('It was on 1995-2-15', question_num: 1, question_text: 'foo', i: nil)

        call_set_custom_value(
          'It was on 1995-2-15',
          {
            limit: 2,
            key: 'foo',
            question_num: 1,
            question_text: 'foo'
          },
          nil
        )

        verify_hash('foo' => placeholder_text)
      end

      it 'displays boolean as string' do
        verify_extras_text('true', question_num: 1, question_text: 'foo', i: nil)

        call_set_custom_value(
          [true],
          {
            key: :foo,
            limit: 0,
            question_num: 1,
            question_text: 'foo'
          },
          nil
        )

        verify_hash(foo: placeholder_text)
      end

      context 'with an index' do
        it 'adds text with line number' do
          verify_extras_text('bar', question_num: 1, question_text: 'foo', i: 0)

          call_set_value(
            {
              limit: 2,
              key: 'foo',
              question_num: 1,
              question_text: 'foo'
            },
            0
          )

          verify_hash('foo' => placeholder_text)
        end
      end
    end

    context 'with a value thats under limit' do
      it 'sets the hash to the value' do
        call_set_value(
          {
            key: :foo,
            limit: 3
          },
          nil
        )

        verify_hash(foo: 'bar')
      end
    end

    context 'when called from array overflow' do
      it 'does not add any text to overflow' do
        expect(extras_generator).not_to receive(:add_text)

        call_set_value({ key: :foo, question_num: 1, question_text: 'Foo' }, nil, true)
        verify_hash(foo: 'bar')
      end
    end
  end

  describe '#transform_data' do
    subject { described_class.new('%m/%d/%Y', extras_generator) }

    let(:form_data) do
      {
        toursOfDuty: [
          {
            discharge: 'honorable',
            foo: nil,
            nestedHash: {
              dutyType: 'title 10',
              nestedTourDate: '2010-09-09',
              nestedBoolean: true
            }
          },
          {
            discharge: 'medical',
            nestedHash: {
              dutyType: 'title 32',
              nestedTourDate: '2010-10-10',
              nestedBoolean: false
            }
          }
        ],
        date: '2017-06-06',
        stringWithDate: 'It was 2017-06-06',
        veteranFullName: 'bob bob',
        nestedHash: {
          nestedHash: {
            married: true,
            nestedDate: '2010-08-05'
          }
        },
        bankAccount: {
          accountNumber: 34_343_434,
          checking: true
        }
      }
    end

    let(:pdftk_keys) do
      {
        date: {
          key: 'form.date',
          format: 'date'
        },
        stringWithDate: {
          key: 'form.stringWithDate'
        },
        veteranFullName: { key: 'form1[0].#subform[0].EnterNameOfApplicantFirstMiddleLast[0]' },
        bankAccount: {
          accountNumber: { key: 'form1[0].#subform[0].EnterACCOUNTNUMBER[0]' },
          checking: { key: 'form1[0].#subform[0].CheckBoxChecking[0]' }
        },
        nestedHash: {
          nestedHash: {
            married: { key: 'form1[0].#subform[1].CheckBoxYes6B[0]' },
            nestedDate: {
              key: 'form1[0].#subform[1].NestedDate[0]',
              format: 'date'
            }
          }
        },
        toursOfDuty: {
          limit: 10,
          discharge: { key: "form1[0].#subform[1].EnterCharacterD#{PdfFill::HashConverter::ITERATOR}[0]" },
          nestedHash: {
            dutyType: { key: "form1[0].#subform[1].EnterTypeOfDutyE#{PdfFill::HashConverter::ITERATOR}[0]" },
            nestedTourDate: {
              key: "form1[0].#subform[1].NestedTourDate[#{PdfFill::HashConverter::ITERATOR}]",
              format: 'date'
            },
            nestedBoolean: {
              key: "form1[0].#subform[1].NestedBoolean[#{PdfFill::HashConverter::ITERATOR}]"
            }
          }
        }
      }
    end

    it 'converts the hash correctly' do
      expect(subject.transform_data(form_data:, pdftk_keys:)).to eq(
        'form1[0].#subform[1].EnterCharacterD0[0]' => 'honorable',
        'form1[0].#subform[1].EnterTypeOfDutyE0[0]' => 'title 10',
        'form1[0].#subform[1].EnterCharacterD1[0]' => 'medical',
        'form1[0].#subform[1].EnterTypeOfDutyE1[0]' => 'title 32',
        'form.date' => '06/06/2017',
        'form.stringWithDate' => 'It was 2017-06-06',
        'form1[0].#subform[0].EnterNameOfApplicantFirstMiddleLast[0]' => 'bob bob',
        'form1[0].#subform[1].CheckBoxYes6B[0]' => 1,
        'form1[0].#subform[1].NestedDate[0]' => '08/05/2010',
        'form1[0].#subform[0].EnterACCOUNTNUMBER[0]' => '34343434',
        'form1[0].#subform[0].CheckBoxChecking[0]' => 1,
        'form1[0].#subform[1].NestedTourDate[0]' => '09/09/2010',
        'form1[0].#subform[1].NestedBoolean[0]' => 1,
        'form1[0].#subform[1].NestedTourDate[1]' => '10/10/2010',
        'form1[0].#subform[1].NestedBoolean[1]' => 0
      )
    end

    context 'when fields get overflowed to extras' do
      let(:form_data) do
        {
          veteranFullName: { first: 'Hubert', last: 'Wolfeschlegelsteinhausenbergerdorff' },
          treatmentProviders: ['Walter Reed, Bethesda MD', 'Silver Oak Recovery Center, Clearwater FL'],
          additionalRemarks: 'Additional Remarks'
        }
      end
      let(:pdftk_keys) do
        {
          veteranFullName: {
            first: {
              key: 'F[0].#subform[2].Veterans_Service_Members_First_Name[0]',
              limit: 12,
              question_num: 1,
              question_text: 'First Name'
            },
            last: {
              key: 'F[0].#subform[2].VeteransLastName[0]',
              limit: 18,
              question_num: 2,
              question_text: 'Last Name'
            }
          },
          additionalRemarks: {
            key: 'form1[0].#subform[0].Additional_Remarks[0]',
            limit: 1,
            question_num: 3,
            question_text: 'Additional Remarks',
            question_type: 'free_text'
          },
          treatmentProviders: {
            limit: 1,
            item_label: 'Treatment facility',
            question_text: 'Provider',
            question_num: 13,
            key: "F[0].#subform[5].Name_And_Location_Of_Treatment_Facility[#{PdfFill::HashConverter::ITERATOR}]"
          }
        }
      end

      it 'calls add_to_extras with the correct data and metadata' do
        verify_extras_text('Hubert',
                           i: nil, question_num: 1, question_text: 'First Name',
                           overflow: false)
        verify_extras_text('Wolfeschlegelsteinhausenbergerdorff',
                           i: nil, question_num: 2, question_text: 'Last Name')
        verify_extras_text('Additional Remarks',
                           i: nil, question_num: 3, question_text: 'Additional Remarks', question_type: 'free_text')
        verify_extras_text('Walter Reed, Bethesda MD',
                           i: 0, question_num: 13, question_text: 'Provider', item_label: 'Treatment facility')
        verify_extras_text('Silver Oak Recovery Center, Clearwater FL',
                           i: 1, question_num: 13, question_text: 'Provider', item_label: 'Treatment facility')
        subject.transform_data(form_data:, pdftk_keys:)
      end
    end
  end

  describe '#handle_overflow_and_label_all' do
    subject { described_class.new('%m/%d/%Y', extras_generator) }

    let(:form_data) do
      [
        { 'name' => 'Aziz', 'description' => 'A short description' },
        { 'name' => 'Puku', 'description' => 'A very long description that exceeds the limit' },
        { 'name' => 'Habibi', 'description' => 'Another description' }
      ]
    end

    let(:pdftk_keys) do
      {
        'name' => {
          key: 'form.name',
          limit: 10,
          question_num: 1,
          question_text: 'Name'
        },
        'description' => {
          key: 'form.description',
          limit: 5,
          question_num: 2,
          question_text: 'Description'
        }
      }
    end

    before do
      allow(extras_generator).to receive(:add_text)
    end

    it 'processes each item and handles overflow correctly' do
      subject.handle_overflow_and_label_all(form_data, pdftk_keys)

      # Verify the form data is set correctly
      # The last item's values should be in the form
      expect(subject.instance_variable_get(:@pdftk_form)).to eq(
        'form.name' => 'Habibi',
        'form.description' => placeholder_text
      )

      # Since from_array_overflow is true, add_text should not be called
      expect(extras_generator).not_to have_received(:add_text)
    end
  end

  describe '#handle_overflow_and_label_first_key' do
    it 'sets the first key to EXTRAS_TEXT in @pdftk_form' do
      pdftk_keys = {
        first_key: 'key1',
        'key1' => { key: 'form_key1' }
      }

      converter.handle_overflow_and_label_first_key(pdftk_keys)

      expect(converter.instance_variable_get(:@pdftk_form)['form_key1']).to eq(placeholder_text)
    end

    it 'does nothing if first_key is not found in pdftk_keys' do
      pdftk_keys = {
        first_key: 'key1',
        'key2' => { key: 'form_key2' }
      }

      converter.handle_overflow_and_label_first_key(pdftk_keys)

      expect(converter.instance_variable_get(:@pdftk_form)).to be_empty
    end

    it 'does nothing if key is not present in key_data' do
      pdftk_keys = {
        first_key: 'key1',
        'key1' => { other_data: 'something' }
      }

      converter.handle_overflow_and_label_first_key(pdftk_keys)

      expect(converter.instance_variable_get(:@pdftk_form)).to be_empty
    end

    it 'sets the first key value to EXTRAS_TEXT even with nested structure' do
      pdftk_keys = {
        first_key: 'key1',
        'key1' => {
          key: 'form_key1',
          'nested_key' => { key: 'form_nested_key' }
        }
      }

      converter.handle_overflow_and_label_first_key(pdftk_keys)

      expect(converter.instance_variable_get(:@pdftk_form)['form_key1']).to eq(placeholder_text)
    end
  end

  describe '#add_to_extras' do
    it 'merges format_options from both array_key_data and key_data' do
      array_key_data = {
        format_options: { label_width: 120, bold_item_label: true }
      }

      key_data = {
        question_num: 1,
        question_text: 'Test Question',
        format_options: { bold_value: true, bold_label: true }
      }

      # The merged format_options should have array_key_data options and key_data options,
      # with key_data options taking precedence
      expected_metadata = {
        question_num: 1,
        question_text: 'Test Question',
        i: 0,
        overflow: true,
        item_label: nil,
        question_type: nil,
        format_options: {
          label_width: 120,
          bold_item_label: true,
          bold_value: true,
          bold_label: true
        }
      }

      expect(extras_generator).to receive(:add_text).with('test value', expected_metadata)

      converter.add_to_extras(key_data, 'test value', 0, array_key_data:)
    end

    it 'passes show_suffix to extras_generator when present in key_data' do
      key_data = {
        question_num: 1,
        question_text: 'Test Question',
        show_suffix: true
      }

      expected_metadata = {
        question_num: 1,
        question_text: 'Test Question',
        show_suffix: true,
        i: nil,
        overflow: true,
        item_label: nil,
        question_type: nil,
        format_options: {}
      }

      expect(extras_generator).to receive(:add_text).with('test value', expected_metadata)

      converter.add_to_extras(key_data, 'test value', nil)
    end

    it 'handles when only key_data has format_options' do
      key_data = {
        question_num: 1,
        question_text: 'Test Question',
        format_options: { bold_value: true, bold_label: true }
      }

      expected_metadata = {
        question_num: 1,
        question_text: 'Test Question',
        i: nil,
        overflow: true,
        item_label: nil,
        question_type: nil,
        format_options: { bold_value: true, bold_label: true }
      }

      expect(extras_generator).to receive(:add_text).with('test value', expected_metadata)

      converter.add_to_extras(key_data, 'test value', nil)
    end

    it 'handles when only array_key_data has format_options' do
      array_key_data = {
        format_options: { label_width: 120, bold_item_label: true },
        item_label: 'Item'
      }

      key_data = {
        question_num: 1,
        question_text: 'Test Question'
      }

      expected_metadata = {
        question_num: 1,
        question_text: 'Test Question',
        i: 0,
        overflow: true,
        item_label: 'Item',
        question_type: nil,
        format_options: { label_width: 120, bold_item_label: true }
      }

      expect(extras_generator).to receive(:add_text).with('test value', expected_metadata)

      converter.add_to_extras(key_data, 'test value', 0, array_key_data:)
    end

    it 'handles when neither has format_options' do
      key_data = {
        question_num: 1,
        question_text: 'Test Question'
      }

      expected_metadata = {
        question_num: 1,
        question_text: 'Test Question',
        i: nil,
        overflow: true,
        item_label: nil,
        question_type: nil,
        format_options: {}
      }

      expect(extras_generator).to receive(:add_text).with('test value', expected_metadata)

      converter.add_to_extras(key_data, 'test value', nil)
    end

    it 'overrides array_key_data options with key_data options when keys conflict' do
      array_key_data = {
        format_options: { label_width: 120, bold_value: false }
      }

      key_data = {
        question_num: 1,
        question_text: 'Test Question',
        format_options: { bold_value: true }
      }

      # The bold_value from key_data should override the one from array_key_data
      expected_metadata = {
        question_num: 1,
        question_text: 'Test Question',
        i: 0,
        overflow: true,
        item_label: nil,
        question_type: nil,
        format_options: {
          label_width: 120,
          bold_value: true
        }
      }

      expect(extras_generator).to receive(:add_text).with('test value', expected_metadata)

      converter.add_to_extras(key_data, 'test value', 0, array_key_data:)
    end

    it 'prevents text from going to extras generator if hide_from_overflow is set' do
      key_data = {
        question_num: 1,
        question_text: 'Test Question',
        hide_from_overflow: true
      }

      expect(extras_generator).not_to receive(:add_text)

      converter.add_to_extras(key_data, 'test value', nil)
    end
  end
end
