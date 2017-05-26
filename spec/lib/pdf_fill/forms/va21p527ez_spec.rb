require 'spec_helper'
require 'pdf_fill/forms/va21p527ez'

describe PdfFill::Forms::VA21P527EZ do
  let(:form_data) do
    {
      'veteranFullName' => {
        'first' => 'john',
        'middle' => 'middle',
        'last' => 'smith',
        'suffix' => 'Sr.'
      }
    }
  end

  describe '#combine_full_name' do
    let(:full_name) do
      form_data['veteranFullName']
    end

    subject do
      described_class.combine_full_name(full_name)
    end

    context 'with missing fields' do
      before do
        full_name.delete('middle')
        full_name.delete('suffix')
      end

      it 'should combine a full name' do
        expect(subject).to eq("john smith")
      end
    end

    context 'with nil full name' do
      let(:full_name) { nil }

      it 'should return nil' do
        expect(subject).to eq(nil)
      end
    end

    it 'should combine a full name' do
      expect(subject).to eq("john middle smith Sr.")
    end
  end

  describe '#merge_fields' do
    it 'should merge the right fields' do
      expect(described_class.merge_fields(form_data)).to eq(
        {"veteranFullName"=>"john middle smith Sr."}
      )
    end
  end
end
