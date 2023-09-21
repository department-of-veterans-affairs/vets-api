# frozen_string_literal: true

def stub_jwt_valid_token_decode
  # mock the JWT decode
  allow_any_instance_of(ClaimsApi::ValidatedToken)
    .to receive(:validate_jwt_values).and_return(true)
end
