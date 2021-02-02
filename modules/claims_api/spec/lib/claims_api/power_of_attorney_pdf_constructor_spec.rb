# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/power_of_attorney_pdf_constructor'
require_relative '../../support/pdf_matcher'

describe ClaimsApi::PowerOfAttorneyPdfConstructor do
  let(:power_of_attorney) { create(:power_of_attorney, :with_full_headers) }

  before do
    Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
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

  after do
    Timecop.return
  end

  it 'fills page one of the pdf' do
    constructor = ClaimsApi::PowerOfAttorneyPdfConstructor.new(power_of_attorney.id)
    signed_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '2122', 'page_1_signed.pdf')
    expected_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '2122', 'signed_filled_page_1.pdf')
    generated_pdf = constructor.fill_pdf(signed_pdf, 1)
    expect(generated_pdf).to match_pdf_content_of(expected_pdf)
  end

  it 'fills page two of the pdf' do
    constructor = ClaimsApi::PowerOfAttorneyPdfConstructor.new(power_of_attorney.id)
    signed_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '2122', 'page_2_signed.pdf')
    expected_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '2122', 'signed_filled_page_2.pdf')
    generated_pdf = constructor.fill_pdf(signed_pdf, 2)
    expect(generated_pdf).to match_pdf_content_of(expected_pdf)
  end
end
