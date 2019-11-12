# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VaForms::Form, type: :model do
  describe 'callbacks' do
    it 'sets the last_revision to the first issued date if blank' do
      form = VaForms::Form.new
      form.form_name = '526ez'
      form.url = 'https://va.gov/va_form/21-526ez.pdf'
      form.title = 'Disability Compensation'
      form.first_issued_on = Time.zone.today - 1.day
      form.pages = 2
      form.sha256 = 'somelongsha'
      form.save
      form.reload
      expect(form.last_revision_on).to eq(form.first_issued_on)
    end
  end
end
