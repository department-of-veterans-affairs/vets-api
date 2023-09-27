# frozen_string_literal: true

require 'rails_helper'
require VAForms::Engine.root.join('spec', 'rails_helper.rb')

RSpec.describe VAForms::FormReloader, type: :job do
  let(:builder) { class_double(VAForms::FormBuilder) }
  let(:reloader) { described_class.new }
  let(:form_data) { reloader.all_forms_data }
  let(:form_count) { form_data.size }

  it 'schedules a child `FormBuilder` job for each form retrieved' do
    VCR.use_cassette('va_forms/gql_forms') do
      form_data.each { |form| VAForms::FormBuilder.perform_async(form) }
      expect(VAForms::FormBuilder.jobs.size).to eq(form_count)
    end
  end
end
