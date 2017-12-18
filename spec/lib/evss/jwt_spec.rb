# frozen_string_literal: true
require 'rails_helper'
require 'evss/jwt'

describe EVSS::Jwt do
  let(:some_random_time) { Time.local(2016, 9, 1, 12, 0, 0) }
  subject(:decrypted_token) do
    JWT.decode(
      described_class.new(current_user).encode,
      described_class::SIGNING_KEY,
      described_class::SIGNING_ALGORITHM
    )
  end

  context 'with an LOA3 user at a given time' do
    let(:current_user) { FactoryBot.build(:user, :loa3) }

    before { Timecop.freeze(some_random_time) }
    after { Timecop.return }

    it 'has the right properties' do
      payload = decrypted_token[0]
      headers = decrypted_token[1]

      expect(payload['correlationIds']).to_not be_nil
      expect(payload['jti']).to be_a_uuid
      expect(payload).to include({
          'iat' => 1472745600,
          'exp' => 1472745900,
          'iss' => 'Vets.gov',
          'assuranceLevel' => 3,
          'email' => current_user.email,
          'firstName' => current_user.first_name,
          'middleName' => current_user.middle_name,
          'lastName' => current_user.last_name,
          'birthDate' => current_user.birth_date,
          'gender' => current_user.gender,
          'prefix' =>"",
          'suffix' =>""
        })
    end
  end
end