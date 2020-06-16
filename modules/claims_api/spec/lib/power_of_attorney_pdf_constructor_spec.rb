# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/power_of_attorney_pdf_constructor'

describe ClaimsApi::PowerOfAttorneyPdfConstructor do
  let(:power_of_attorney) { create(:power_of_attorney, :with_full_headers) }

  before do
    b64_image = File.read('modules/claims_api/spec/fixtures/signature_b64.txt')
    power_of_attorney.form_data = {
      'signatures': {
        'veteran': b64_image,
        'representative': b64_image
      },
      'veteran': {
        'address': {
          'numberAndStreet': '2719 Hyperion Ave',
          'city': 'Los Angeles',
          'state': 'CA',
          'country': 'US',
          'zipFirstFive': '92264'
        },
        'phone': {
          'areaCode': '555',
          'ohoneNumber': '5551337'
        }
      },
      'serviceOrganization': {
        'address': {
          'numberAndStreet': '2719 Hyperion Ave',
          'city': 'Los Angeles',
          'state': 'CA',
          'country': 'US',
          'zipFirstFive': '92264'
        }
      }
    }
    power_of_attorney.save
  end

  it 'fills page one of the pdf' do
    constructor = ClaimsApi::PowerOfAttorneyPdfConstructor.new(power_of_attorney.id)
    signed_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '2122', 'page_1_signed.pdf')
    expected_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '2122', 'signed_filled_page_1.pdf')
    generated_pdf = constructor.fill_pdf(signed_pdf, 1)
    generated_pdf_md5 = Digest::MD5.digest(File.read(generated_pdf))
    expected_pdf_md5 = Digest::MD5.digest(File.read(expected_pdf))
    File.delete(generated_pdf) if File.exist?(generated_pdf)
    expect(generated_pdf_md5).to eq(expected_pdf_md5)
  end

  it 'fills page two of the pdf' do
    constructor = ClaimsApi::PowerOfAttorneyPdfConstructor.new(power_of_attorney.id)
    signed_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '2122', 'page_2_signed.pdf')
    expected_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '2122', 'signed_filled_page_2.pdf')
    generated_pdf = constructor.fill_pdf(signed_pdf, 2)
    generated_pdf_md5 = Digest::MD5.digest(File.read(generated_pdf))
    expected_pdf_md5 = Digest::MD5.digest(File.read(expected_pdf))
    File.delete(generated_pdf) if File.exist?(generated_pdf)
    expect(generated_pdf_md5).to eq(expected_pdf_md5)
  end
end
