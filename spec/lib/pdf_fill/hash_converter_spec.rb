require 'spec_helper'
require 'pdf_fill/hash_converter'

describe PdfFill::HashConverter do
  describe '#transform_data' do
    let(:form_data) do
      {
        toursOfDuty: [
          {
            discharge: 'honorable',
            nestedHash: {
              dutyType: 'title 10'
            }
          },
          {
            discharge: 'medical',
            nestedHash: {
              dutyType: 'title 32'
            }
          },
        ],
        veteranFullName: 'bob bob',
        nestedHash: {
          nestedHash: {
            married: true
          },
        },
        bankAccount: {
          accountNumber: 34343434,
          checking: true
        }
      }
    end

    let(:pdftk_keys) do
      {
        veteranFullName: 'form1[0].#subform[0].EnterNameOfApplicantFirstMiddleLast[0]',
        bankAccount: {
          accountNumber: 'form1[0].#subform[0].EnterACCOUNTNUMBER[0]',
          checking: 'form1[0].#subform[0].CheckBoxChecking[0]'
        },
        nestedHash: {
          nestedHash: {
            married: 'form1[0].#subform[1].CheckBoxYes6B[0]'
          },
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
      binding.pry; fail
      described_class.new.transform_data(
        form_data: form_data,
        pdftk_keys: pdftk_keys
      )
    end
  end
end
