# frozen_string_literal: true

require 'support/pdf_fill_helper'

RSpec.configure do |config|
  %i[model controller request].each do |type|
    config.include PdfFillHelper, type:
  end
end
