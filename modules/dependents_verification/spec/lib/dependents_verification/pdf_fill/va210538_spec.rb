# frozen_string_literal: true

require 'rails_helper'

def basic_class
  DependentsVerification::PdfFill::Va210538.new({})
end

describe DependentsVerification::PdfFill::Va210538 do
  let(:form_data) do
    {}
  end

  let(:new_form_class) do
    described_class.new(form_data)
  end

  def class_form_data
    new_form_class.instance_variable_get(:@form_data)
  end

  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2024-03-21 00:00:00 EDT' do
      actual = File.read("#{DependentsVerification::MODULE_PATH}/spec/fixtures/pdf_fill/21-0538/kitchen_sink.json")
      expected = File.read("#{DependentsVerification::MODULE_PATH}/spec/fixtures/pdf_fill/21-0538/merge_fields.json")
      expect(described_class.new(JSON.parse(actual)).merge_fields.to_json).to eq(JSON.parse(expected).to_json)
    end
  end
end
