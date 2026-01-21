# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe 'AccreditedRepresentativePortal::V0::AuthorizeAsRepresentative', type: :request do
  describe 'GET /accredited_representative_portal/v0/authorize_as_representative' do
    context 'when not authenticated' do
      it 'responds with unauthorized (401)' do
        get '/accredited_representative_portal/v0/authorize_as_representative'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      let(:user) { create(:representative_user, email: 'rep@example.com', all_emails: ['rep@example.com']) }

      before do
        login_as(user)
      end

      context 'and user is an accredited representative' do
        before do
          allow_any_instance_of(AccreditedRepresentativePortal::PowerOfAttorneyHolderMemberships)
            .to receive(:empty?)
            .and_return(false)
        end

        it 'returns 204 No Content' do
          get '/accredited_representative_portal/v0/authorize_as_representative'
          expect(response).to have_http_status(:no_content)
          expect(response.body).to be_blank
        end
      end

      context 'and user is not an accredited representative' do
        before do
          allow_any_instance_of(AccreditedRepresentativePortal::PowerOfAttorneyHolderMemberships)
            .to receive(:power_of_attorney_holders)
            .and_return([])
        end

        it 'returns 403 Forbidden' do
          get '/accredited_representative_portal/v0/authorize_as_representative'
          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'and PowerOfAttorneyHolderMemberships raises Forbidden (e.g., OGC conflict/none)' do
        before do
          allow_any_instance_of(AccreditedRepresentativePortal::PowerOfAttorneyHolderMemberships)
            .to receive(:power_of_attorney_holders).and_raise(Common::Exceptions::Forbidden)
        end

        it 'returns 403 Forbidden' do
          get '/accredited_representative_portal/v0/authorize_as_representative'
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
