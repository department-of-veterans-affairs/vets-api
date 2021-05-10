# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/poa_pdf_constructor/organization'

describe ClaimsApi::PoaPdfConstructor::Organization do
  let(:temp) { create(:power_of_attorney, :with_full_headers) }

  before do
    Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
    b64_image = File.read('modules/claims_api/spec/fixtures/signature_b64.txt')
    temp.form_data = {
      signatures: {
        veteran: b64_image,
        representative: b64_image
      },
      veteran: {
        address: {
          numberAndStreet: '2719 Hyperion Ave',
          city: 'Los Angeles',
          state: 'CA',
          country: 'US',
          zipFirstFive: '92264'
        },
        phone: {
          areaCode: '555',
          phoneNumber: '5551337'
        }
      },
      serviceOrganization: {
        address: {
          numberAndStreet: '2719 Hyperion Ave',
          city: 'Los Angeles',
          state: 'CA',
          country: 'US',
          zipFirstFive: '92264'
        }
      }
    }
    temp.save
  end

  after do
    Timecop.return
  end

  it 'construct pdf' do
    expected_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '21-22', 'signed_filled_final.pdf')
    expect(Digest::MD5.file(expected_pdf.to_s)).to eq(Digest::MD5.file(expected_pdf.to_s))
  end
end
