#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'pdf_fill/filler'

puts(PdfFill::Filler.fill_ancillary_form(
  JSON.parse(File.read('spec/fixtures/pdf_fill/21-0781V2/overflow.json')),
  12345,
  '21-0781V2',
  { extras_redesign: true, show_jumplinks: true, flatten: true }
))