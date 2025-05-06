# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/generate_pdf/generate_pdf_provider'

RSpec.describe GeneratePdfProvider do
  it 'always raises an error on the GeneratePdfProvider base module' do
    expect do
      subject.generate_526_pdf({}, nil)
    end.to raise_error NotImplementedError
  end
end
