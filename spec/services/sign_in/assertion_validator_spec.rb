# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::AssertionValidator do
  describe '#perform' do
    subject { SignIn::AssertionValidator.new(assertion:).perform }

    let(:private_key) { assertion_certificate.private_key }
    let!(:assertion_certificate) { create(:sign_in_certificate) }
    let(:assertion_payload) do
      {
        iss:,
        aud:,
        sub:,
        jti:,
        iat:,
        exp:,
        service_account_id:,
        scopes:
      }
    end
    let(:iss) { 'some-iss' }
    let(:aud) { token_route }
    let(:sub) { 'some-sub' }
    let(:jti) { 'some-jti' }
    let(:iat) { 1.month.ago.to_i }
    let(:exp) { 1.month.since.to_i }
    let(:scopes) { service_account_config.scopes }
    let(:service_account_id) { service_account_config.service_account_id }
    let(:service_account_config) { create(:service_account_config) }
    let(:service_account_audience) { service_account_config.access_token_audience }
    let(:assertion_encode_algorithm) { SignIn::Constants::Auth::ASSERTION_ENCODE_ALGORITHM }
    let(:assertion) { JWT.encode(assertion_payload, private_key, 'RS256') }
    let(:token_route) { "https://#{Settings.hostname}#{SignIn::Constants::Auth::TOKEN_ROUTE_PATH}" }

    context 'when the clients certificates are active' do
      before do
        service_account_config.certs << assertion_certificate
      end

      context 'when jwt was not encoded with expected signature' do
        let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
        let(:expected_error) { SignIn::Errors::AssertionSignatureMismatchError }
        let(:expected_error_message) { 'Assertion body does not match signature' }

        it 'raises assertion signature mismatch error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when jwt is expired' do
        let(:exp) { 1.month.ago.to_i }
        let(:expected_error) { SignIn::Errors::AssertionExpiredError }
        let(:expected_error_message) { 'Assertion has expired' }

        it 'raises assertion malformed error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when jwt was not properly encoded' do
        let(:assertion) { JWT.encode(assertion_payload, nil) }
        let(:expected_error) { SignIn::Errors::AssertionMalformedJWTError }
        let(:expected_error_message) { 'Assertion is malformed' }

        it 'raises assertion malformed error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when jwt is valid' do
        let(:assertion) { JWT.encode(assertion_payload, private_key, assertion_encode_algorithm) }
        let(:expected_error) { SignIn::Errors::ServiceAccountAssertionAttributesError }

        context 'and service account config in assertion does not match an existing service account config' do
          let(:service_account_id) { 'some-service-account-id' }
          let(:expected_error) { SignIn::Errors::ServiceAccountConfigNotFound }
          let(:expected_error_message) { 'Service account config not found' }

          it 'raises service account config not found error' do
            expect { subject }.to raise_error(expected_error, expected_error_message)
          end
        end

        context 'and service account id in assertion is missing' do
          let(:expected_error) { SignIn::Errors::ServiceAccountConfigNotFound }
          let(:expected_error_message) { 'Service account config not found' }

          before { assertion_payload.delete(:service_account_id) }

          context 'and issuer in assertion matches an existing service account config' do
            let(:iss) { service_account_config.service_account_id }

            it 'returns a service account access token' do
              expect(subject).to be_a(SignIn::ServiceAccountAccessToken)
            end
          end

          context 'and issuer in assertion does not match an existing service account config' do
            let(:iss) { 'some-iss' }

            it 'raises service account config not found error' do
              expect { subject }.to raise_error(expected_error, expected_error_message)
            end
          end
        end

        context 'and service account config in assertion does match an existing service account config' do
          let(:service_account_id) { service_account_config.service_account_id }

          context 'and iss does not equal service account config audience' do
            let(:expected_error_message) { 'Invalid issuer' }

            context 'and iss equals service account id' do
              let(:iss) { service_account_id }

              it 'decodes the assertion and returns a token' do
                expect(subject).to be_a(SignIn::ServiceAccountAccessToken)
              end
            end

            context 'and iss does not equal service account id' do
              let(:iss) { 'some-iss' }

              it 'raises service account assertion attributes error' do
                expect { subject }.to raise_error(expected_error, expected_error_message)
              end
            end
          end

          context 'and iss equals service account config audience' do
            let(:iss) { service_account_audience }

            context 'and audience is not present' do
              let(:expected_error_message) { "Invalid audience. Expected [\"#{token_route}\"], received <none>" }

              before { assertion_payload.delete(:aud) }

              it 'raises service account assertion attributes error' do
                expect { subject }.to raise_error(expected_error, expected_error_message)
              end
            end

            context 'and audience does not match token route' do
              let(:aud) { 'some-aud' }
              let(:expected_error_message) { "Invalid audience. Expected [\"#{token_route}\"], received #{aud}" }

              it 'raises service account assertion attributes error' do
                expect { subject }.to raise_error(expected_error, expected_error_message)
              end
            end

            context 'and audience matches token route' do
              let(:aud) { token_route }

              context 'and scopes are not present' do
                before { assertion_payload.delete(:scopes) }

                context 'and service account config scopes are not present' do
                  let(:service_account_config) do
                    create(:service_account_config, certs: [assertion_certificate], scopes: [])
                  end

                  it 'does not raise an error' do
                    expect { subject }.not_to raise_error
                  end
                end

                context 'and service account config scopes are present' do
                  let(:expected_error_message) { 'Invalid scopes' }

                  it 'raises service account assertion attributes error' do
                    expect { subject }.to raise_error(expected_error, expected_error_message)
                  end
                end
              end

              context 'and scopes are not a subset of service account config scopes' do
                let(:scopes) { ['some-scopes'] }
                let(:expected_error_message) { 'Invalid scopes' }

                it 'raises service account assertion attributes error' do
                  expect { subject }.to raise_error(expected_error, expected_error_message)
                end
              end

              context 'and scopes are a subset of service account config scopes' do
                let(:scopes) { [service_account_config.scopes.first] }

                context 'and subject is not present' do
                  let(:expected_error_message) { 'Missing required claim sub' }

                  before { assertion_payload.delete(:sub) }

                  it 'raises service account assertion attributes error' do
                    expect { subject }.to raise_error(expected_error, expected_error_message)
                  end
                end

                context 'and subject is present' do
                  context 'and iat is missing' do
                    let(:expected_error_message) { 'Missing required claim iat' }

                    before { assertion_payload.delete(:iat) }

                    it 'raises service account assertion attributes error' do
                      expect { subject }.to raise_error(expected_error, expected_error_message)
                    end
                  end

                  context 'and iat is in the future' do
                    let(:iat) { 1.month.from_now.to_i }
                    let(:expected_error_message) { 'Invalid iat' }

                    it 'raises service account assertion attributes error' do
                      expect { subject }.to raise_error(expected_error, expected_error_message)
                    end
                  end

                  context 'and exp is missing' do
                    let(:expected_error_message) { 'Missing required claim exp' }

                    before { assertion_payload.delete(:exp) }

                    it 'raises service account assertion attributes error' do
                      expect { subject }.to raise_error(expected_error, expected_error_message)
                    end
                  end

                  context 'and iat & exp are present and valid' do
                    it 'returns service account access token with expected service account id' do
                      expect(subject.service_account_id).to eq(service_account_id)
                    end

                    it 'returns service account access token with expected audience' do
                      expect(subject.audience).to eq(service_account_audience)
                    end

                    it 'returns service account access token with expected scopes' do
                      expect(subject.scopes).to eq(scopes)
                    end

                    it 'returns service account access token with expected user identifier' do
                      expect(subject.user_identifier).to eq(sub)
                    end
                  end
                end
              end
            end
          end
        end

        context 'and user_attributes claim is provided' do
          let(:service_account_config) do
            create(:service_account_config, certs: [assertion_certificate], access_token_user_attributes: ['icn'])
          end
          let(:assertion_payload) do
            {
              iss: service_account_audience,
              aud: token_route,
              sub:,
              jti:,
              iat:,
              exp: 1.month.from_now.to_i,
              service_account_id: service_account_config.service_account_id,
              scopes: [service_account_config.scopes.first],
              user_attributes:
            }
          end

          context 'and contains attributes that are not allowed for the service account' do
            let(:user_attributes) { { some_attribute: 'some-value' } }
            let(:expected_error) { SignIn::Errors::ServiceAccountAssertionAttributesError }
            let(:expected_error_message) { 'Invalid user attributes' }

            it 'raises service account assertion attributes error' do
              expect { subject }.to raise_error(expected_error, expected_error_message)
            end
          end

          context 'and does not contain attributes that are not allowed for the service account' do
            let(:user_attributes) { { icn: 'some-value' } }

            it 'returns the service account access token with the user attributes' do
              expect(subject.user_attributes).to eq(user_attributes)
            end
          end
        end
      end
    end

    context 'when the certificate is expired' do
      let!(:assertion_certificate) { build(:sign_in_certificate, :expired) }
      let(:expected_error) { SignIn::Errors::AssertionCertificateExpiredError }
      let(:expected_error_message) { 'Certificates are expired' }

      before do
        assertion_certificate.save(validate: false)
        config_certificate = service_account_config.config_certificates.new(cert: assertion_certificate)
        config_certificate.save(validate: false)
      end

      it 'raises the expected error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end
  end
end
