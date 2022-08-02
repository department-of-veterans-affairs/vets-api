# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1095B, type: :model do
  subject { create :form1095_b }

  describe 'validations' do
    describe '#unique_icn_and_year' do
      context 'unique icn + year combo' do
        let(:dup) { subject.dup }

        it 'requires unique icn and year' do
          expect(dup).not_to be_valid
        end

        it 'allows new years form to be created' do
          dup.tax_year = 2020

          expect(dup).to be_valid
        end
      end

      context 'form_data validations' do
        let(:invalid_form_data) { JSON.parse(subject.form_data) }
        let(:invalid_form) { build :form1095_b, form_data: invalid_form_data.to_json }

        it 'requires a name' do
          invalid_form_data['first_name'] = nil
          invalid_form = subject.dup
          invalid_form.form_data = invalid_form_data.to_json

          expect(invalid_form).not_to be_valid
        end
      end
    end
  end

  describe 'pdf_testing' do
    describe 'valid pdf generation' do
      it 'generates pdf string for valid 1095_b' do
        expect(subject.pdf_file.class).to eq(String)
      end
    end

    describe 'invalid PDF generation' do
      let(:inv_year_form) { create :form1095_b, veteran_icn: '654678976543678', tax_year: 2008 }

      it 'fails if no template PDF for the tax_year' do
        expect { inv_year_form.pdf_file }.to raise_error(RuntimeError, /1095-B for tax year 2008 not supported/)
      end
    end
  end

  describe 'txt_testing' do
    describe 'valid text file generation' do
      it 'generates text string for valid 1095_b' do
        expect(subject.txt_file.class).to eq(String)
      end
    end

    describe 'invalid txt generation' do
      let(:inv_year_form) { create :form1095_b, veteran_icn: '654678976543678', tax_year: 2008 }

      it 'fails if no template txt file for the tax_year' do
        expect { inv_year_form.txt_file }.to raise_error(RuntimeError, /1095-B for tax year 2008 not supported/)
      end
    end
  end

  describe 'scopes' do
    let!(:multi_search_form_2) { create :form1095_b, veteran_icn: '123456787654321', tax_year: 2020 }
    let!(:multi_search_form_1) { create :form1095_b, veteran_icn: '123456787654321' }
    let!(:multi_search_form_3) { create :form1095_b, veteran_icn: '123456787654321', tax_year: 2019 }

    let(:expected_val_1) { [[subject.tax_year, subject.updated_at]] }
    let(:expected_val_2) do
      [
        [multi_search_form_1.tax_year, multi_search_form_1.updated_at],
        [multi_search_form_2.tax_year, multi_search_form_2.updated_at],
        [multi_search_form_3.tax_year, multi_search_form_3.updated_at]
      ]
    end

    it 'returns individual available form' do
      expect(Form1095B.available_forms(subject.veteran_icn)).to eq(expected_val_1)
    end

    it 'returns available forms in descending order by tax year' do
      expect(Form1095B.available_forms(multi_search_form_1.veteran_icn)).to eq(expected_val_2)
    end

    it 'expects empty array if no available forms exist' do
      expect(Form1095B.available_forms('876543234567')).to eq([])
    end
  end
end
