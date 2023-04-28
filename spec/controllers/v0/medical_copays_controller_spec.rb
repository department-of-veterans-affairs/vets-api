# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::MedicalCopaysController, type: :controller do
  let(:user) { build(:user, :loa3) }

  context 'when not logged in' do
    it 'returns unauthorized' do
      get(:index)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'user is not enrolled in VA healthcare' do
    let(:user) { build(:user, edipi: nil, icn: nil) }

    before do
      sign_in_as(user)
    end

    it 'returns forbidden' do
      get(:index)
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'user is enrolled in VA healthcare with copays' do
    before do
      sign_in_as(user)
    end

    it 'returns success' do
      allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_copays).and_return(
        {
          data: [
            {
              'fooBar' => 'bar'
            }
          ],
          status: 200
        }
      )
      get(:index)
      expect(response).to have_http_status(:ok)
    end
  end

  describe '#show' do
    before do
      sign_in_as(user)
    end

    it 'returns success when record is found' do
      allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_copay_by_id).and_return(
        {
          data: [
            {
              'id' => '123',
              'fooBar' => 'bar'
            }
          ],
          status: 200
        }
      )
      get(:show, params: { id: '123' })
      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 when record is not found' do
      allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_copay_by_id).and_raise(
        MedicalCopays::VBS::Service::StatementNotFound
      )
      get(:show, params: { id: '123' })
      expect(response).to have_http_status(:not_found)
    end
  end

  describe '#send_statement_notifications' do
    it 'returns a success message when notifications are sent' do
      post(:send_statement_notifications, params: { statements: [] })
      expect(response).to have_http_status(:ok)
    end
  end
end
