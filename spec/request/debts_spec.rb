RSpec.describe 'Debts API Endpoint', type: :request do
  include SchemaMatchers

  let(:user) { create(:user, :loa3) }

  describe 'GET /debts' do
    context 'with a veteran who has debts' do
      it 'returns a 200 with the array of debts' do
        VCR.use_cassette('dmc/200_get_debt_letter_details') do
          get '/v0/debts'
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('debts')
        end
      end
    end

    context 'with a veteran who does not have debts' do
      it 'returns a 404' do
        VCR.use_cassette('dmc/404_get_debt_letter_details') do
          get '/v0/debts'
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
