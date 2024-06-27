# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::OnsiteNotificationsController, type: :controller do
  private_key = OpenSSL::PKey::EC.new(File.read('spec/support/certificates/notification-private.pem'))

  let(:template_id) { 'f9947b27-df3b-4b09-875c-7f76594d766d' }
  let(:params) do
    {
      onsite_notification: {
        template_id:,
        va_profile_id: '1'
      }
    }
  end

  before do
    allow_any_instance_of(V0::OnsiteNotificationsController).to receive(:public_key).and_return(
      OpenSSL::PKey::EC.new(
        File.read('spec/support/certificates/notification-public.pem')
      )
    )
  end

  describe 'with a signed in user' do
    let(:user) { create(:user, :loa3) }
    let!(:onsite_notification) { create(:onsite_notification, va_profile_id: user.vet360_id) }
    let!(:dismissed_onsite_notification) do
      create(:onsite_notification, va_profile_id: user.vet360_id, dismissed: true)
    end

    before do
      sign_in_as(user)
    end

    describe '#index' do
      it "returns the user's undismissed onsite notifications" do
        get(:index)

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['data'].map { |d| d['id'] }).to eq(
          [onsite_notification.id.to_s]
        )
      end

      it "returns all of the user's onsite notifications, including dismissed ones" do
        get :index, params: { include_dismissed: true }

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['data'].map do |d|
                 d['id']
               end).to contain_exactly(onsite_notification.id.to_s, dismissed_onsite_notification.id.to_s)
      end

      describe 'pagination metadata' do
        before do
          4.times { create(:onsite_notification, va_profile_id: user.vet360_id) }
        end

        it 'generates correctly when given no pagination params' do
          get :index

          payload = JSON.parse(response.body)
          pagination = payload['meta']['pagination']
          expect(pagination['current_page']).to eq(1)
          expect(pagination['per_page']).to eq(WillPaginate.per_page)
          expect(pagination['total_pages']).to eq(1)
          expect(pagination['total_entries']).to eq(5)
        end

        it 'generates correctly when given paging params' do
          get :index, params: { page: 1, per_page: 2 }

          payload = JSON.parse(response.body)
          pagination = payload['meta']['pagination']
          expect(pagination['current_page']).to eq(1)
          expect(pagination['per_page']).to eq(2)
          expect(pagination['total_pages']).to eq(3)
          expect(pagination['total_entries']).to eq(5)
        end

        it 'returns the first page and default page size when given invalid paging params' do
          default_per_page = WillPaginate.per_page
          [{
            page: -1,
            per_page: default_per_page,
            expected_page: 1
          }, {
            page: 0,
            per_page: default_per_page,
            expected_page: 1
          }, {
            page: 10,
            per_page: default_per_page,
            expected_page: 10
          }, {
            page: 1,
            per_page: -1,
            expected_page: 1
          }, {
            page: 0,
            per_page: -1,
            expected_page: 1
          }, {
            page: -1,
            per_page: -1,
            expected_page: 1
          }].each do |params|
            get :index, params: params.compact.except(:expected_page)

            payload = JSON.parse(response.body)
            pagination = payload['meta']['pagination']
            expect(pagination['current_page']).to eq(params[:expected_page])
            expect(pagination['per_page']).to eq(WillPaginate.per_page)
            expect(pagination['total_pages']).to eq(1)
            expect(pagination['total_entries']).to eq(5)
          end
        end
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
          onsite_notification.update!(va_profile_id: '98765')
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
      jwt = JWT.encode({ user: 'va_notify', iat: Time.current.to_i, exp: 1.minute.from_now.to_i }, private_key, 'ES256')
      request.headers['Authorization'] = "Bearer #{jwt}"
    end

    context 'with valid params' do
      it 'creates an onsite notification' do
        post(:create, params:, as: :json)

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
        post(:create, params:, as: :json)

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
    context 'with missing Authorization header' do
      it 'returns 403' do
        request.headers['Authorization'] = nil
        post(:create, params:)
        expect(response.status).to eq(403)
      end
    end

    context 'with invalid Authorization header' do
      it 'returns 403' do
        request.headers['Authorization'] = 'Bearer foo'
        post(:create, params:)
        expect(response.status).to eq(403)
      end
    end

    context 'with valid authentication' do
      it 'returns 200' do
        request.headers['Authorization'] = "Bearer #{JWT.encode(
          {
            user: 'va_notify',
            iat: Time.current.to_i,
            exp: 1.minute.from_now.to_i
          }, private_key, 'ES256'
        )}"

        post(:create, params:)
        expect(response.status).to eq(200)
      end
    end

    context 'with expired token' do
      it 'returns 403' do
        payload = { user: 'va_notify', iat: Time.current.to_i, exp: 1.minute.ago.to_i }
        request.headers['Authorization'] = "Bearer #{JWT.encode(payload, private_key, 'ES256')}"

        post(:create, params:)
        expect(response.status).to eq(403)
      end
    end

    context 'with missing issued at' do
      it 'returns 403' do
        payload = { user: 'va_notify', exp: 1.minute.ago.to_i }
        request.headers['Authorization'] = "Bearer #{JWT.encode(payload, private_key, 'ES256')}"

        post(:create, params:)
        expect(response.status).to eq(403)
      end
    end

    context 'with missing expiration' do
      it 'returns 403' do
        payload = { user: 'va_notify', iat: Time.current.to_i }
        request.headers['Authorization'] = "Bearer #{JWT.encode(payload, private_key, 'ES256')}"

        post(:create, params:)
        expect(response.status).to eq(403)
      end
    end
  end
end
