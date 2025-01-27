# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/iam_session_helper'

RSpec.describe 'legacy Mobile::V0::User::Logout', type: :request do
  # this is considered legacy because it's specific to IAM users and is no longer in use by the mobile client.
  # this should be deleted when iam is sunset.
  describe 'GET /mobile/v0/user/logout' do
    before do
      iam_sign_in(build(:iam_user))
      allow_any_instance_of(IAMUser).to receive(:idme_uuid).and_return('b2fab2b5-6af0-45e1-a9e2-394347af91ef')
    end

    context 'with a 200 response' do
      before do
        get '/mobile/v0/user/logout', headers: iam_headers
      end

      it 'returns an ok response' do
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
