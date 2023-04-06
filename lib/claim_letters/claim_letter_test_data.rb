# frozen_string_literal: true
# rubocop:disable all

require "ostruct"

module ClaimLetterTestData
  TEST_FILE_PATH = Rails.root.join 'lib', 'claim_letters', 'test_pdf', '1.pdf'
  TEST_DATA = [
    OpenStruct.new(
      document_id: '{B686D3C3-8720-41B5-8640-4F5CECD1A1BE}',
      series_id: '{BDE11169-689C-4614-A55C-E6E3E4A8B3F3}',
      version: '1',
      type_description: 'Decision Rating Letter 2',
      type_id: '340',
      doc_type: '340',
      subject: nil,
      received_at: Date.new(2009,5,12),
      source: 'VBMS',
      mime_type: 'application/pdf',
      alt_doc_types: '',
      restricted: false,
      upload_date: Date.new(2020,5,9)
    ),
    OpenStruct.new(
      document_id: '{B686D3C3-8720-41B5-8640-4F5CECD1A1BD}',
      series_id: '{BDE11169-689C-4614-A55C-E6E3E4A8B3F4}',
      version: '1',
      type_description: 'Decision Rating Letter',
      type_id: '339',
      doc_type: '339',
      subject: nil,
      received_at: Date.new(2009,5,12),
      source: 'VBMS',
      mime_type: 'application/pdf',
      alt_doc_types: '',
      restricted: false,
      upload_date: Date.new(2020,5,10)
    ),
    OpenStruct.new(
      document_id: '{B686D3C3-8720-41B5-8640-4F5CECD1A1BC}',
      series_id: '{BDE11169-689C-4614-A55C-E6E3E4A8B3F5}',
      version: '1',
      type_description: 'Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)',
      type_id: '184',
      doc_type: '184',
      subject: nil,
      received_at: Date.new(2009,5,12),
      source: 'VBMS',
      mime_type: 'application/pdf',
      alt_doc_types: '',
      restricted: false,
      upload_date: Date.new(2020,5,8)
    ),
    OpenStruct.new(
      document_id: '{4688C825-7309-42DA-8133-15E71278D64D}',
      series_id: '{D2E8C734-1C92-4B88-97F8-7D4CCE2D8499}',
      version: '1',
      type_description: 'Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)',
      type_id: '184',
      doc_type: '184',
      subject: "Intent to File",
      received_at: Date.new(2022,4,11),
      source: 'VBMS',
      mime_type: 'application/pdf',
      alt_doc_types: '',
      restricted: false,
      upload_date: Date.new(2022,4,12)
    ),
    OpenStruct.new(
      document_id: '{99DA7758-A10A-43F4-A056-C961C76A2DDF}',
      series_id: '{3C1B98EC-687C-47B1-B8EB-2989D05ED1F5}',
      version: '1',
      type_description: 'Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)',
      type_id: '184',
      doc_type: '184',
      subject: nil,
      received_at: Date.new(2022,8,31),
      source: 'VBMS',
      mime_type: 'application/pdf',
      alt_doc_types: '',
      restricted: false,
      upload_date: Date.new(2022,9,1)
    ),
    OpenStruct.new(
      document_id: '{87B6DE5D-CD79-4D15-B6DC-A5F9A324DC3E}',
      series_id: '{EC1B5F0C-E3FB-4A41-B93F-E1A88D549CDF}',
      version: '1',
      type_description: 'Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)',
      type_id: '184',
      doc_type: '184',
      subject: nil,
      received_at: Date.new(2022,9,22),
      source: 'VBMS',
      mime_type: 'application/pdf',
      alt_doc_types: '',
      restricted: false,
      upload_date: Date.new(2022,9,23)
    ),
    OpenStruct.new(
      document_id: '{27832B64-2D88-4DEE-9F6F-DF80E4CAAA87}',
      series_id: '{350C072A-90A1-43A7-AD50-A5C9C54C357A}',
      version: '1',
      type_description: 'Notification Letter (e.g. VA 20-8993, VA 21-0290, PCGL)',
      type_id: '184',
      doc_type: '184',
      subject: nil,
      received_at: Date.new(2022,9,22),
      source: 'VBMS',
      mime_type: 'application/pdf',
      alt_doc_types: '',
      restricted: false,
      upload_date: Date.new(2022,9,23)
    ),
    OpenStruct.new(
      document_id: '{27832B64-2D88-4DEE-9F6F-DF80E4CAAA88}',
      series_id: '{350C072A-90A1-43A7-AD50-A5C9C54C357B}',
      version: '1',
      type_description: 'Board Of Appeals Decision Letter',
      type_id: '27',
      doc_type: '27',
      subject: nil,
      received_at: Date.new(2022,12,22),
      source: 'VBMS',
      mime_type: 'application/pdf',
      alt_doc_types: '',
      restricted: false,
      upload_date: Date.new(2022,12,23)
    )
  ].freeze
end
