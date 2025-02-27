# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1095::Delete1095BsJob, type: :job do
  describe 'perform' do
    it 'deletes all 1095b forms prior to the current tax year' do
      create(:form1095_b, tax_year: Form1095B.current_tax_year - 5)
      create(:form1095_b, tax_year: Form1095B.current_tax_year - 3)
      create(:form1095_b, tax_year: Form1095B.current_tax_year - 1)
      current_tax_year_form = create(:form1095_b, tax_year: Form1095B.current_tax_year)
      current_year_form = create(:form1095_b, tax_year: Form1095B.current_tax_year + 1)

      subject.perform

      expect(Form1095B.pluck(:id)).to eq([current_tax_year_form.id, current_year_form.id])
    end
  end
end
