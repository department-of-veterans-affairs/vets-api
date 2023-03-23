# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe UserSessionForm, type: :model do
  include SAML::ResponseBuilder

  let(:loa3_user) do
    build(:user, :loa3, uuid: saml_attributes[:uuid],
                        idme_uuid: saml_attributes[:uuid])
  end
  let(:saml_response) do
    build_saml_response(
      authn_context: 'myhealthevet',
      level_of_assurance: '3',
      attributes: saml_attributes,
      existing_attributes: nil,
      issuer: 'https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20'
    )
  end

  context 'with ID.me UUID in SAML' do
    let(:saml_attributes) do
      build(:ssoe_idme_mhv_premium, va_eauth_gcIds: va_eauth_gc_ids)
    end
    let(:va_eauth_gc_ids) do
      ['1012853550V207686^NI^200M^USVHA^P|'\
       '552151510^PI^989^USVHA^A|'\
       '943571^PI^979^USVHA^A|'\
       '12345748^PI^200MH^USVHA^A|'\
       '1012853550^PN^200PROV^USDVA^A|'\
       '7219295^PI^983^USVHA^A|'\
       '552161765^PI^984^USVHA^A|'\
       '2107307560^NI^200DOD^USDOD^A|'\
       '7b9b5861203244f0b99b02b771159044^PN^200VIDM^USDVA^A|'\
       '0e1bb5723d7c4f0686f46ca4505642ad^PN^200VIDM^USDVA^A|'\
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

    context 'and ID.me UUID not in SAML GCids' do
      let(:va_eauth_gc_ids) do
        ['1012853550V207686^NI^200M^USVHA^P|'\
         '552151510^PI^989^USVHA^A|'\
         '943571^PI^979^USVHA^A|'\
         '12345748^PI^200MH^USVHA^A|'\
         '1012853550^PN^200PROV^USDVA^A|'\
         '7219295^PI^983^USVHA^A|'\
         '552161765^PI^984^USVHA^A|'\
         '2107307560^NI^200DOD^USDOD^A|'\
         '12345748^PI^200MHS^USVHA^A']
      end
      let(:add_person_response) do
        MPI::Responses::AddPersonResponse.new(status:, parsed_codes:)
      end
      let(:status) { 'OK' }
      let(:parsed_codes) { { icn: saml_attributes[:va_eauth_icn] } }

      before do
        allow_any_instance_of(MPI::Service).to receive(:add_person_implicit_search).and_return(add_person_response)
      end

      it 'adds the ID.me UUID to the existing mpi record' do
        expect_any_instance_of(MPI::Service).to receive(:add_person_implicit_search)
        UserSessionForm.new(saml_response)
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
        let!(:user_verification) { create(:idme_user_verification, user_account:) }
        let(:idme_uuid) { user_verification.idme_uuid }
        let(:add_person_response) do
          MPI::Responses::AddPersonResponse.new(status:, parsed_codes:)
        end
        let(:status) { 'OK' }
        let(:parsed_codes) { { icn: saml_attributes[:va_eauth_icn] } }

        before do
          allow_any_instance_of(MPI::Service).to receive(:add_person_implicit_search).and_return(add_person_response)
        end

        it 'uses the injected identifier as the user key' do
          subject = UserSessionForm.new(saml_response)
          subject.persist
          expect(User.find(idme_uuid)).to be_truthy
          expect(UserIdentity.find(idme_uuid)).to be_truthy
        end

        it 'adds the identifier to an existing mpi record' do
          expect_any_instance_of(MPI::Service).to receive(:add_person_implicit_search)
          UserSessionForm.new(saml_response)
        end

        context 'when failure occurs during adding identifier to existing mpi record' do
          let(:status) { 'some-not-successful-status' }
          let(:sentry_log) { "Failed Add CSP ID to MPI FAILED, idme: #{idme_uuid}" }
          let(:sentry_level) { :warn }

          it 'logs a message to sentry' do
            expect_any_instance_of(UserSessionForm).to receive(:log_message_to_sentry).with(sentry_log, sentry_level)
            UserSessionForm.new(saml_response)
          end
        end
      end
    end

    context 'and Login.gov UUID is present in SAML' do
      let(:saml_attributes) do
        build(:ssoe_logingov_ial2)
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
    end
  end
end
