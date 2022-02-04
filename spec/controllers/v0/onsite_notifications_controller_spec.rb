# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::OnsiteNotificationsController, type: :controller do
  private_key = OpenSSL::PKey::EC.new(File.read('spec/support/certificates/notification-private.pem'))

  let(:template_id) { 'f9947b27-df3b-4b09-875c-7f76594d766d' }
  let(:params) do
    {
      onsite_notification: {
        template_id: template_id,
        va_profile_id: '1'
      }
    }
  end

  before do
    allow(Settings.notifications).to receive(:public_key).and_return(
      File.read(
        'spec/support/certificates/notification-public.pem'
      )
    )
  end

  describe 'with a signed in user' do
    let(:user) { create(:user, :loa3) }
    let!(:onsite_notification) { create(:onsite_notification, va_profile_id: user.vet360_id) }

    before do
      sign_in_as(user)
    end

    describe '#index' do
      it 'returns the users onsite notifications' do
        get(:index)

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['data'].map { |d| d['id'] }).to eq(
          [onsite_notification.id.to_s]
        )
      end
    end

    describe '#update' do
      def do_update(attributes = { dismissed: true })
        patch(
          :update,
          params: {
            id: onsite_notification.id,
            onsite_notification: attributes
          },
          as: :json
        )
      end

      context 'when a user is trying to update another users onsite_notification' do
        before do
          onsite_notification.update!(va_profile_id: '1')
        end

        it 'returns 404' do
          do_update

          expect(response.status).to eq(404)
          expect(onsite_notification.reload.dismissed).to eq(false)
        end
      end

      context 'with a validation error' do
        before do
          # rubocop:disable Rails/SkipsModelValidations
          onsite_notification.update_column(:template_id, '1')
          # rubocop:enable Rails/SkipsModelValidations
        end

        it 'returns validation error' do
          do_update

          expect(JSON.parse(response.body)).to eq(
            { 'errors' =>
              [{ 'title' => 'Template is not included in the list',
                 'detail' => 'template-id - is not included in the list',
                 'code' => '100',
                 'source' => { 'pointer' => 'data/attributes/template-id' },
                 'status' => '422' }] }
          )
          expect(response.status).to eq(422)
        end
      end

      it 'doesnt update va_profile_id' do
        do_update(va_profile_id: '5')
        expect(response.status).to eq(200)

        expect(onsite_notification.reload.va_profile_id).not_to eq('5')
      end

      it "updates the notification's dismissed status" do
        do_update

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['data']['id']).to eq(onsite_notification.id.to_s)
        expect(onsite_notification.reload.dismissed).to eq(true)
      end
    end
  end

  describe '#create' do
    before do
      request.headers['Authorization'] = "Bearer #{JWT.encode({ user: 'va_notify' }, private_key, 'ES256')}"
    end

    context 'with valid params' do
      it 'creates an onsite notification' do
        post(:create, params: params, as: :json)

        expect(response.status).to eq(200)

        res = JSON.parse(response.body)
        expect(res['data']['attributes'].keys).to eq(%w[template_id va_profile_id dismissed created_at
                                                        updated_at])

        onsite_notification = OnsiteNotification.last
        expect(onsite_notification.template_id).to eq(template_id)
        expect(onsite_notification.va_profile_id).to eq('1')
      end
    end

    context 'with invalid params' do
      before do
        params[:onsite_notification][:template_id] = '1'
      end

      it 'returns a validation error' do
        post(:create, params: params, as: :json)

        expect(JSON.parse(response.body)).to eq(
          { 'errors' =>
            [{ 'title' => 'Template is not included in the list',
               'detail' => 'template-id - is not included in the list',
               'code' => '100',
               'source' => { 'pointer' => 'data/attributes/template-id' },
               'status' => '422' }] }
        )
        expect(response.status).to eq(422)
      end
    end
  end

  describe 'authentication' do
    def self.test_authorization_header(header, status)
      it "returns #{status}" do
        request.headers['Authorization'] = header
        post(:create, params: params)

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
