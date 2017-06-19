# frozen_string_literal: true
require 'spec_helper'
require 'pdf_fill/hash_converter'

describe PdfFill::HashConverter do
  let(:hash_converter) do
    described_class.new('%m/%d/%Y')
  end

  describe '#set_value' do
    def verify_extras_text(text)
      the_text = hash_converter.instance_variable_get(:@extras_generator).instance_variable_get(:@text)

      expect(the_text).to eq(
        "Additional Information\n\n#{text}\n"
      )
    end

    def verify_hash(hash)
      expect(hash_converter.instance_variable_get(:@pdftk_form)).to eq(
        hash
      )
    end

    context "with a value that's over limit" do
      it 'should add text to the extras page' do
        hash_converter.set_value(
          :foo,
          'bar',
          {
            limit: 2,
            question: 1
          },
          nil
        )

        verify_extras_text('1: bar')
        verify_hash(foo: "See add'l info page")
      end
    end
  end

  describe '#transform_data' do
    let(:form_data) do
      {
        toursOfDuty: [
          {
            discharge: 'honorable',
            foo: nil,
            nestedHash: {
              dutyType: 'title 10'
            }
          },
          {
            discharge: 'medical',
            nestedHash: {
              dutyType: 'title 32'
            }
          }
        ],
        date: '2017-06-06',
        veteranFullName: 'bob bob',
        nestedHash: {
          nestedHash: {
            married: true
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
        date: 'form.date',
        veteranFullName: 'form1[0].#subform[0].EnterNameOfApplicantFirstMiddleLast[0]',
        bankAccount: {
          accountNumber: 'form1[0].#subform[0].EnterACCOUNTNUMBER[0]',
          checking: 'form1[0].#subform[0].CheckBoxChecking[0]'
        },
        nestedHash: {
          nestedHash: {
            married: 'form1[0].#subform[1].CheckBoxYes6B[0]'
          }
        },
        toursOfDuty: {
          discharge: "form1[0].#subform[1].EnterCharacterD#{PdfFill::HashConverter::ITERATOR}[0]",
          nestedHash: {
            dutyType: "form1[0].#subform[1].EnterTypeOfDutyE#{PdfFill::HashConverter::ITERATOR}[0]"
          }
        }
      }
    end

    it 'should convert the hash correctly' do
      expect(
        described_class.new('%m/%d/%Y').transform_data(
          form_data: form_data,
          pdftk_keys: pdftk_keys
        )
      ).to eq(
        'form1[0].#subform[1].EnterCharacterD0[0]' => 'honorable',
        'form1[0].#subform[1].EnterTypeOfDutyE0[0]' => 'title 10',
        'form1[0].#subform[1].EnterCharacterD1[0]' => 'medical',
        'form1[0].#subform[1].EnterTypeOfDutyE1[0]' => 'title 32',
        'form.date' => '06/06/2017',
        'form1[0].#subform[0].EnterNameOfApplicantFirstMiddleLast[0]' => 'bob bob',
        'form1[0].#subform[1].CheckBoxYes6B[0]' => 1,
        'form1[0].#subform[0].EnterACCOUNTNUMBER[0]' => '34343434',
        'form1[0].#subform[0].CheckBoxChecking[0]' => 1
      )
    end
  end
end
