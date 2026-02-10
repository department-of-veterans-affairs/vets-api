# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe UserSessionForm, type: :model do
  include SAML::ResponseBuilder

  let(:loa3_user) do
    build(:user, :loa3, uuid: saml_attributes[:uuid],
                        idme_uuid: saml_attributes[:uuid])
  end
  let(:correlation_mpi_record) { build(:mpi_profile, ssn: correlation_mpi_ssn) }
  let(:find_profile_response) { create(:find_profile_response, profile: correlation_mpi_record) }

  let(:authn_context) { 'http://idmanagement.gov/ns/assurance/loa/3/vets' }
  let(:saml_response) do
    build_saml_response(
      authn_context:,
      level_of_assurance: '3',
      attributes: saml_attributes,
      existing_attributes: nil,
      issuer: 'https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20'
    )
  end

  let(:mpi_service) { instance_double(MPI::Service) }
  let(:correlation_mpi_ssn) { saml_attributes[:va_eauth_pnid] }
  let(:va_eauth_pnid) { '123456789' }

  before do
    allow(MPI::Service).to receive(:new).and_return(mpi_service)
    allow(mpi_service).to receive(:find_profile_by_identifier).with(anything).and_return(find_profile_response)
  end

  shared_examples 'a skipped correlation ssn mismatch check' do
    it 'does not call MPI to find the correlation record' do
      expect(mpi_service).not_to receive(:find_profile_by_identifier)
      UserSessionForm.new(saml_response)
    end

    it 'return nil when calling user_attribute_mismatch_checks' do
      expect_any_instance_of(UserSessionForm).to receive(:user_attribute_mismatch_checks).and_return(nil)
      UserSessionForm.new(saml_response)
    end
  end

  shared_examples 'a correlation ssn mismatch error' do
    let(:expected_error_message) do
      "Attribute mismatch: ssn in primary view doesn't match correlation record"
    end

    let(:identifier) { saml_attributes[:va_eauth_uid] }
    let(:identifier_type) { saml_attributes['va_eauth_csid'].downcase }
    let(:view_type) { MPI::Constants::CORRELATION_VIEW }

    it 'looks up correlation record in MPI and raises' do
      expect(mpi_service).to receive(:find_profile_by_identifier)
        .with(identifier:, identifier_type:, view_type:)
        .and_return(find_profile_response)

      expect { UserSessionForm.new(saml_response) }
        .to raise_error(SAML::UserAttributeError, expected_error_message)
    end
  end

  context 'with ID.me UUID in SAML' do
    let(:saml_attributes) do
      build(:ssoe_idme_mhv_premium, va_eauth_gcIds: va_eauth_gc_ids, va_eauth_pnid:)
    end
    let(:va_eauth_gc_ids) do
      ['1012853550V207686^NI^200M^USVHA^P|' \
       '552151510^PI^989^USVHA^A|' \
       '943571^PI^979^USVHA^A|' \
       '12345748^PI^200MH^USVHA^A|' \
       '1012853550^PN^200PROV^USDVA^A|' \
       '7219295^PI^983^USVHA^A|' \
       '552161765^PI^984^USVHA^A|' \
       '2107307560^NI^200DOD^USDOD^A|' \
       '7b9b5861203244f0b99b02b771159044^PN^200VIDM^USDVA^A|' \
       '0e1bb5723d7c4f0686f46ca4505642ad^PN^200VIDM^USDVA^A|' \
       '12345748^PI^200MHS^USVHA^A']
    end

    it 'instantiates cleanly' do
      UserSessionForm.new(saml_response)
    end

    it 'instantiates with a Session SSOe transactionid' do
      form = UserSessionForm.new(saml_response)
      expect(form.session[:ssoe_transactionid])
        .to eq(saml_attributes['va_eauth_transactionid'])
    end

    it 'instantiates with an expected id.me UUID' do
      form = UserSessionForm.new(saml_response)
      expect(form.user_identity.idme_uuid)
        .to eq(saml_attributes['va_eauth_uid'])
    end

    context 'when the saml_ssn is blank' do
      let(:va_eauth_pnid) { '' }

      it_behaves_like 'a skipped correlation ssn mismatch check'
    end

    context 'when the saml_ssn does not match the correlation record ssn' do
      let(:correlation_mpi_ssn) { '987654321' }

      it_behaves_like 'a correlation ssn mismatch error'
    end

    context 'when the correlation_record is not found in MPI' do
      let(:find_profile_response) { create(:find_profile_response, profile: nil) }

      it_behaves_like 'a correlation ssn mismatch error'
    end

    context 'and ID.me UUID not in SAML GCids' do
      let(:va_eauth_gc_ids) do
        ['1012853550V207686^NI^200M^USVHA^P|' \
         '552151510^PI^989^USVHA^A|' \
         '943571^PI^979^USVHA^A|' \
         '12345748^PI^200MH^USVHA^A|' \
         '1012853550^PN^200PROV^USDVA^A|' \
         '7219295^PI^983^USVHA^A|' \
         '552161765^PI^984^USVHA^A|' \
         '2107307560^NI^200DOD^USDOD^A|' \
         '12345748^PI^200MHS^USVHA^A']
      end
      let(:add_person_response) do
        MPI::Responses::AddPersonResponse.new(status:, parsed_codes:)
      end
      let(:status) { 'OK' }
      let(:parsed_codes) { { icn: saml_attributes[:va_eauth_icn] } }

      before do
        allow(mpi_service).to receive(:add_person_implicit_search).and_return(add_person_response)
      end

      it 'adds the ID.me UUID to the existing mpi record' do
        UserSessionForm.new(saml_response)
        expect(mpi_service).to have_received(:add_person_implicit_search)
      end
    end
  end

  context 'with ID.me UUID not present in SAML' do
    context 'and Login.gov UUID is not present in SAML' do
      let(:saml_attributes) do
        build(:ssoe_inbound_mhv_premium, va_eauth_gcIds: [''])
      end
      let(:icn) { saml_attributes[:va_eauth_icn] }
      let(:user_account) { user_verification.user_account }
      let!(:user_verification) { create(:idme_user_verification) }

      context 'and there are no existing user account mappings for the user' do
        let(:user_account) { nil }
        let(:user_verification) { nil }
        let(:expected_error) { SAML::UserAttributeError }

        it 'raises a saml user attribute error' do
          expect { UserSessionForm.new(saml_response) }.to raise_error(expected_error)
        end
      end

      context 'when credential identifier can be found on existing account' do
        let(:user_account) { create(:user_account, icn: saml_attributes[:va_eauth_icn]) }
        let!(:user_verification) { create(:user_verification, user_account:) }
        let(:idme_uuid) { user_verification.idme_uuid }
        let(:add_person_response) do
          MPI::Responses::AddPersonResponse.new(status:, parsed_codes:)
        end
        let(:status) { 'OK' }
        let(:parsed_codes) { { icn: saml_attributes[:va_eauth_icn] } }

        before do
          allow(mpi_service).to receive(:add_person_implicit_search).and_return(add_person_response)
        end

        it 'uses the user account uuid as the user key' do
          subject = UserSessionForm.new(saml_response)
          subject.persist
          expect(User.find(user_account.id)).to be_truthy
          expect(UserIdentity.find(user_account.id)).to be_truthy
        end

        it 'adds the identifier to an existing mpi record' do
          UserSessionForm.new(saml_response)
          expect(mpi_service).to have_received(:add_person_implicit_search)
        end

        context 'when failure occurs during adding identifier to existing mpi record' do
          let(:status) { 'some-not-successful-status' }

          it 'logs a message to Rails logger' do
            expect(Rails.logger).to receive(:warn).with(
              '[UserSessionForm] Failed Add CSP ID to MPI',
              idme_uuid:
            )
            UserSessionForm.new(saml_response)
          end
        end
      end
    end

    context 'and Login.gov UUID is present in SAML' do
      let(:authn_context) { 'http://idmanagement.gov/ns/assurance/ial/2/mfa' }
      let(:saml_attributes) do
        build(:ssoe_logingov_ial2, va_eauth_pnid:)
      end

      it 'instantiates cleanly' do
        UserSessionForm.new(saml_response)
      end

      it 'instantiates with a Session SSOe transactionid' do
        form = UserSessionForm.new(saml_response)
        expect(form.session[:ssoe_transactionid])
          .to eq(saml_attributes['va_eauth_transactionid'])
      end

      it 'instantiates with an expected login.gov UUID' do
        form = UserSessionForm.new(saml_response)
        expect(form.user_identity.logingov_uuid)
          .to eq(saml_attributes['va_eauth_uid'])
      end

      context 'when the saml_ssn is blank' do
        let(:va_eauth_pnid) { '' }

        it_behaves_like 'a skipped correlation ssn mismatch check'
      end

      context 'when the saml_ssn does not match the correlation record ssn' do
        let(:correlation_mpi_ssn) { '987654321' }

        it_behaves_like 'a correlation ssn mismatch error'
      end

      context 'when the correlation_record is not found in MPI' do
        let(:find_profile_response) { create(:find_profile_response, profile: nil) }

        it_behaves_like 'a correlation ssn mismatch error'
      end
    end

    context 'and service_type is MHV' do
      let(:authn_context) { SAML::UserAttributes::SSOe::INBOUND_AUTHN_CONTEXT }
      let(:saml_attributes) do
        build(:ssoe_inbound_mhv_premium,
              va_eauth_multifactor: ['True'])
      end

      it_behaves_like 'a skipped correlation ssn mismatch check'
    end
  end
end
