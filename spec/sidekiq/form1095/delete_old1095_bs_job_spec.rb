# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1095::DeleteOld1095BsJob, type: :job do
  describe 'perform' do
    let!(:current_tax_year_form) { create(:form1095_b, tax_year: Form1095B.current_tax_year) }
    let!(:current_year_form) { create(:form1095_b, tax_year: Form1095B.current_tax_year + 1) }

    it 'deletes all 1095b forms prior to the current tax year' do
      create(:form1095_b, tax_year: Form1095B.current_tax_year - 5)
      create(:form1095_b, tax_year: Form1095B.current_tax_year - 3)
      create(:form1095_b, tax_year: Form1095B.current_tax_year - 1)

      expect(Rails.logger).to receive(:info).with('Form1095B Deletion Job: Begin deleting 3 old Form1095B files')
      expect(Rails.logger).to receive(:info).with(
        /Form1095B Deletion Job: Finished deleting old Form1095B files in \d+\.\d+ seconds/
      )

      subject.perform

      expect(Form1095B.pluck(:id)).to contain_exactly(current_tax_year_form.id, current_year_form.id)
    end

    it 'uses an optional limit parameter' do
      oldest_form = create(:form1095_b, tax_year: Form1095B.current_tax_year - 5)
      older_form = create(:form1095_b, tax_year: Form1095B.current_tax_year - 3)
      old_form = create(:form1095_b, tax_year: Form1095B.current_tax_year - 1)

      expect(Rails.logger).to receive(:info).with('Form1095B Deletion Job: Begin deleting 2 old Form1095B files')
      expect(Rails.logger).to receive(:info).with(
        /Form1095B Deletion Job: Finished deleting old Form1095B files in \d+\.\d+ seconds/
      )

      subject.perform(2)

      expect(Form1095B.where(id: [oldest_form.id, older_form.id, old_form.id]).count).to eq(1)
      expect(Form1095B.where(id: [current_tax_year_form.id, current_year_form.id]).count).to eq(2)
    end

    it 'logs a message and deletes nothing if there are no forms to delete' do
      expect(Rails.logger).to receive(:info).with('Form1095B Deletion Job: No old Form1095B records to delete')

      subject.perform

      expect(Form1095B.pluck(:id)).to contain_exactly(current_tax_year_form.id, current_year_form.id)
    end
  end
end
