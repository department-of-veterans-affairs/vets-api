# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/hash_converter'

describe PdfFill::HashConverter do
  let(:hash_converter) do
    described_class.new('%m/%d/%Y', extras_generator)
  end
  let(:extras_generator) { instance_double(PdfFill::ExtrasGenerator) }

  def verify_extras_text(text, metadata)
    metadata[:overflow] = true unless metadata.key?(:overflow)
    metadata[:item_label] = nil unless metadata.key?(:item_label)
    metadata[:question_type] = nil unless metadata.key?(:question_type)
    expect(extras_generator).to receive(:add_text).with(text, metadata).once
  end

  describe '#set_value' do
    def verify_hash(hash)
      expect(hash_converter.instance_variable_get(:@pdftk_form)).to eq(
        hash
      )
    end

    def call_set_value(*args)
      final_args = ['bar'] + args
      hash_converter.set_value(*final_args)
    end

    def call_set_custom_value(value, *args)
      final_args = [value] + args
      hash_converter.set_value(*final_args)
    end

    context 'with a dollar value' do
      it 'adds text to the extras page' do
        verify_extras_text('$bar', question_num: 1, question_text: 'foo', i: nil)

        call_set_value(
          {
            key: :foo,
            dollar: true,
            limit: 2,
            question_num: 1,
            question_text: 'foo'
          },
          nil
        )
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

        verify_hash(foo: "See add'l info page")
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

        verify_hash('foo' => "See add'l info page")
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

        verify_hash('foo' => "See add'l info page")
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

        verify_hash(foo: "See add'l info page")
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

          verify_hash('foo' => "See add'l info page")
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
          treatmentProviders: ['Walter Reed, Bethesda MD', 'Silver Oak Recovery Center, Clearwater FL']
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
        verify_extras_text('Walter Reed, Bethesda MD',
                           i: 0, question_num: 13, question_text: 'Provider', item_label: 'Treatment facility')
        verify_extras_text('Silver Oak Recovery Center, Clearwater FL',
                           i: 1, question_num: 13, question_text: 'Provider', item_label: 'Treatment facility')
        subject.transform_data(form_data:, pdftk_keys:)
      end
    end
  end
end
