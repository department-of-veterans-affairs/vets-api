# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1095B, type: :model do
  subject { create(:form1095_b) }

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
        let(:invalid_form) { build(:form1095_b, form_data: invalid_form_data.to_json) }

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
      let(:inv_year_form) { create(:form1095_b, veteran_icn: '654678976543678', tax_year: 2008) }

      it 'fails if no template PDF for the tax_year' do
        expect { inv_year_form.pdf_file }.to raise_error(Common::Exceptions::UnprocessableEntity)
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
      let(:inv_year_form) { create(:form1095_b, veteran_icn: '654678976543678', tax_year: 2008) }

      it 'fails if no template txt file for the tax_year' do
        expect { inv_year_form.txt_file }.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end
end
