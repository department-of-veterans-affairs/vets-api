# frozen_string_literal: true

require 'rails_helper'
require 'evss/auth_headers'

describe EVSS::AuthHeaders do
  subject { described_class.new(current_user) }

  context 'with an LoA3 user' do
    let(:current_user) { build(:user, :loa3) }

    it 'has the right LoA' do
      expect(subject.to_h['va_eauth_assurancelevel']).to eq '3'
    end

    it 'has only lowercase first letters in key names' do
      # EVSS requires us to pass the HTTP headers as lowercase
      expect(subject.to_h.find { |k, _| k.match(/^[[:upper:]]/) }).to be_nil
    end

    it 'includes the users birls id' do
      expect(subject.to_h['va_eauth_birlsfilenumber']).to eq current_user.birls_id
    end
  end

  context 'with an LoA1 user' do
    let(:current_user) { build(:user, :loa1) }

    it 'has the right LoA' do
      expect(subject.to_h['va_eauth_assurancelevel']).to eq '1'
    end
  end

  describe '#to_h' do
    let(:current_user) { build(:user, :loa3) }
    let(:headers) { subject.to_h }

    context 'with some nil values' do
      before do
        allow(current_user).to receive_messages(ssn: nil, edipi: nil)
      end

      it 'does not return nil header values' do
        expect(headers.values.include?(nil)).to be false
      end

      it 'sets any nil headers values to an empty string', :aggregate_failures do
        expect(headers['va_eauth_dodedipnid']).to eq ''
        expect(headers['va_eauth_pnid']).to eq ''
      end

      it 'does not modify non-nil header values', :aggregate_failures do
        expect(headers['va_eauth_firstName']).to eq current_user.first_name
        expect(headers['va_eauth_lastName']).to eq current_user.last_name
      end

      it 'handles nil date values' do
        current_user.last_signed_in = nil
        expect(headers['va_eauth_issueinstant']).to eq ''
      end
    end

    context 'va_eauth_authorization header field' do
      let(:authorization_response) { JSON.parse(headers['va_eauth_authorization'])['authorizationResponse'] }
      let(:expected_id_type) { 'SSN' }
      let(:expected_id) { current_user.ssn }
      let(:expected_edi) { current_user.edipi }
      let(:expected_first_name) { current_user.first_name }
      let(:expected_last_name) { current_user.last_name }
      let(:expected_birth_date) { Formatters::DateFormatter.format_date(current_user.birth_date, :datetime_iso8601) }

      it 'returns common authorization response fields' do
        expect(authorization_response['idType']).to eq expected_id_type
        expect(authorization_response['id']).to eq expected_id
        expect(authorization_response['edi']).to eq expected_edi
        expect(authorization_response['firstName']).to eq expected_first_name
        expect(authorization_response['lastName']).to eq expected_last_name
        expect(authorization_response['birthDate']).to eq expected_birth_date
      end

      context 'when user is not a dependent' do
        let(:expected_status) { 'VETERAN' }

        it 'returns VETERAN in status field' do
          expect(authorization_response['status']).to eq expected_status
        end

        it 'does not return additional authorization response fields' do
          expect(authorization_response['headOfFamily']).to be_nil
        end
      end

      context 'when user is a dependent' do
        let(:current_user) { build(:dependent_user_with_relationship, :loa3) }
        let(:head_of_family) { authorization_response['headOfFamily'] }
        let(:expected_status) { 'DEPENDENT' }

        it 'returns DEPENDENT in status field' do
          expect(authorization_response['status']).to eq expected_status
        end

        context 'and user has veteran relationships' do
          let(:user_relationship_attributes) { current_user.relationships.first.get_full_attributes.profile }
          let(:expected_id_type) { 'SSN' }
          let(:expected_id) { user_relationship_attributes.ssn }
          let(:expected_edi) { user_relationship_attributes.edipi }
          let(:expected_first_name) { user_relationship_attributes.given_names.first }
          let(:expected_last_name) { user_relationship_attributes.family_name }
          let(:expected_birth_date) do
            Formatters::DateFormatter.format_date(user_relationship_attributes.birth_date, :datetime_iso8601)
          end

          it 'returns head of family hash' do
            expect(head_of_family).not_to be_nil
          end

          it 'returns expected values inside head of family hash' do
            expect(head_of_family['idType']).to eq expected_id_type
            expect(head_of_family['id']).to eq expected_id
            expect(head_of_family['edi']).to eq expected_edi
            expect(head_of_family['firstName']).to eq expected_first_name
            expect(head_of_family['lastName']).to eq expected_last_name
            expect(head_of_family['birthDate']).to eq expected_birth_date
          end
        end

        context 'and user has no relationships' do
          before do
            allow(current_user).to receive(:relationships).and_return(nil)
          end

          it 'does not return additional authorization response fields' do
            expect(head_of_family).to be_nil
          end
        end
      end
    end
  end
end
