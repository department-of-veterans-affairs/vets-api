# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::NotificationsController, type: :controller do
  private_key = OpenSSL::PKey::EC.new(File.read('spec/support/certificates/notification-private.pem'))

  before do
    allow(Settings.notifications).to receive(:public_key).and_return(
      File.read(
        'spec/support/certificates/notification-public.pem'
      )
    )
  end

  describe 'authentication' do
    def self.test_authorization_header(header, status)
      it "returns #{status}" do
        request.headers['Authorization'] = header
        post(:create)

        expect(response.status).to eq(status)
      end
    end

    context 'with missing Authorization header' do
      test_authorization_header(
        nil,
        403
      )
    end

    context 'with invalid Authorization header' do
      test_authorization_header(
        'Bearer foo',
        403
      )

      test_authorization_header(
        'foo',
        403
      )
    end

    context 'with valid authentication' do
      test_authorization_header(
        "Bearer #{JWT.encode({ user: 'va_notify' }, private_key, 'ES256')}",
        200
      )
    end
  end
end
