# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v1/mapper_helpers/auth_headers_lookup'

describe ClaimsApi::V1::AuthHeadersLookup do
  let(:mock_pdf_mapper) do
    Class.new do
      include ClaimsApi::V1::AuthHeadersLookup

      def initialize(auth_headers = {})
        @auth_headers = auth_headers
      end
    end
  end

  let(:auth_headers) do
    {
      va_eauth_pnid: '000000345',
      va_eauth_firstName: 'John',
      va_eauth_lastName: 'Doe',
      va_eauth_birlsfilenumber: '009876543',
      va_eauth_birthdate: '1949-05-06'
    }
  end

  # PDF mapper class receives other params, keeping it simple for the test
  let(:instance) { mock_pdf_mapper.new(auth_headers) }

  it 'maps known keys correctly' do
    expect(instance.get_auth_header(:first_name)).to eq('John')
    expect(instance.get_auth_header(:last_name)).to eq('Doe')
    expect(instance.get_auth_header(:birth_date)).to eq('1949-05-06')
    expect(instance.get_auth_header(:birls_file_number)).to eq('009876543')
    expect(instance.get_auth_header(:pnid)).to eq('000000345')
  end

  # we should never need to raise this but still want to put a guard in place
  it 'raises error for unknown keys' do
    expect { instance.get_auth_header(:invalid) }.to raise_error(ArgumentError)
  end
end
