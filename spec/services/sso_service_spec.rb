# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SSOService do
  before(:each) do
    subject.persist_authentication!
  end

  describe 'MHV Identity' do
    context 'Basic' do
      subject { setup_sso_service_instance('myhealthevet', 'Basic') }

      it "has a #new_user_identity which responds to #sign_in" do
        verify_user_identity_value(
          subject,
          sign_in: { service_name: 'myhealthevet' }
        )
      end

      context 'with ID.me LOA3' do
        it "has a #new_user_identity which responds to #sign_in" do
          verify_user_identity_value(
            subject,
            sign_in: { service_name: 'myhealthevet' }
          )
          subject2 = setup_sso_service_instance('idme', '3')
          verify_user_identity_value(
            subject2,
            sign_in: { service_name: 'idme' }
          )
          subject2.persist_authentication!
          verify_user_identity_value(
            subject2,
            sign_in: { service_name: 'myhealthevet' }
          )
        end
      end
    end

    context 'Advanced' do
      subject { setup_sso_service_instance('myhealthevet', 'Advanced') }

      it "has a #new_user_identity which responds to #sign_in" do
        verify_user_identity_value(
          subject,
          sign_in: { service_name: 'myhealthevet' }
        )
      end
    end

    context 'Premium' do
      subject { setup_sso_service_instance('myhealthevet', 'Premium') }

      it "has a #new_user_identity which responds to #sign_in" do
        verify_user_identity_value(
          subject,
          sign_in: { service_name: 'myhealthevet' }
        )
      end
    end
  end

  describe 'DS Logon Identity' do
    context 'dslogon assurance 1' do
      subject { setup_sso_service_instance('dslogon', '1') }

      it "has a #new_user_identity which responds to #sign_in" do
        verify_user_identity_value(
          subject,
          sign_in: { service_name: 'dslogon' }
        )
      end

      context 'with ID.me LOA3' do
        it "has a #new_user_identity which responds to #sign_in" do
          verify_user_identity_value(
            subject,
            sign_in: { service_name: 'dslogon' }
          )
          subject2 = setup_sso_service_instance('idme', '3')
          verify_user_identity_value(
            subject2,
            sign_in: { service_name: 'idme' }
          )
          subject2.persist_authentication!
          verify_user_identity_value(
            subject2,
            sign_in: { service_name: 'dslogon' }
          )
        end
      end
    end

    context 'dslogon assurance 2' do
      subject { setup_sso_service_instance('dslogon', '2') }

      it "has a #new_user_identity which responds to #sign_in" do
        verify_user_identity_value(
          subject,
          sign_in: { service_name: 'dslogon' }
        )
      end
    end
  end

  describe 'IDme Identity' do
    context 'idme assurance 1' do
      subject { setup_sso_service_instance('idme', '1') }

      it "has a #new_user_identity which responds to #sign_in" do
        verify_user_identity_value(
          subject,
          sign_in: { service_name: 'idme' }
        )
      end
    end

    context 'idme assurance 3' do
      subject { setup_sso_service_instance('idme', '3') }

      it "has a #new_user_identity which responds to #sign_in" do
        verify_user_identity_value(
          subject,
          sign_in: { service_name: 'idme' }
        )
      end
    end
  end

  context 'invalid saml response' do
    let(:saml_response) { OneLogin::RubySaml::Response.new('') }
    subject { described_class.new(saml_response) }

    it 'has Blank response error' do
      expect(subject.valid?).to be_falsey
      expect(subject.errors.full_messages).to eq(['Blank response'])
    end

    it '#persist_authentication! handles saml response errors' do
      expect(SAML::AuthFailHandler).to receive(:new).with(subject.saml_response).and_call_original
      subject.persist_authentication!
    end
  end

  def verify_user_identity_value(sso_service_instance, key_value_pairs)
    key_value_pairs.each do |k, v|
      expect(sso_service_instance.new_user_identity.send(k)).to eq(v)
    end
  end

  def setup_sso_service_instance(type, level)
    response_partial = File.read("#{::Rails.root}/spec/fixtures/files/saml_responses/#{response_file(type, level)}")
    decrypted_document_partial = REXML::Document.new(response_partial)
    saml_response = instance_double(OneLogin::RubySaml::Response, attributes: saml_attributes(type, level),
                                                                  decrypted_document: decrypted_document_partial,
                                                                  is_a?: true,
                                                                  is_valid?: true)
    described_class.new(saml_response)
  end

  def response_file(type, level)
    case type
    when 'myhealthevet'
      'mhv.xml'
    when 'dslogon'
      'dslogon.xml'
    when 'idme'
      level == 1 ? 'loa1.xml' : 'loa3.xml'
    end
  end

  def saml_attributes(type, level)
    case type
    when 'myhealthevet'
      OneLogin::RubySaml::Attributes.new(
        'mhv_icn' => ['1012853550V207686'],
        'mhv_profile' => ["{\"accountType\":\"#{level}\"}"],
        'mhv_uuid' => ['12345748'],
        'email' => ['kam+tristanmhv@adhocteam.us'],
        'multifactor' => [false],
        'uuid' => ['0e1bb5723d7c4f0686f46ca4505642ad'],
        'level_of_assurance' => []
      )
    when 'idme'
      OneLogin::RubySaml::Attributes.new(
        'uuid'               => ['0e1bb5723d7c4f0686f46ca4505642ad'],
        'email'              => ['kam+tristanmhv@adhocteam.us'],
        'fname'              => ['Tristan'],
        'lname'              => ['MHV'],
        'mname'              => [''],
        'social'             => ['11122333'],
        'gender'             => ['male'],
        'birth_date'         => ['1735-10-30'],
        'level_of_assurance' => [3],
        'multifactor'        => [true]
      )
    when 'dslogon'
      OneLogin::RubySaml::Attributes.new(
        'dslogon_status' => ['DEPENDENT'],
        'dslogon_assurance' => [level],
        'dslogon_gender' => ['M'],
        'dslogon_deceased' => ['false'],
        'dslogon_idtype' => ['ssn'],
        'uuid' => ['0e1bb5723d7c4f0686f46ca4505642ad'],
        'dslogon_uuid' => ['1606997570'],
        'email' => ['kam+tristanmhv@adhocteam.us'],
        'multifactor' => ['true'],
        'level_of_assurance' => ['3'],
        'dslogon_birth_date' => [],
        'dslogon_fname' => ['Tristan'],
        'dslogon_lname' => ['MHV'],
        'dslogon_mname' => [''],
        'dslogon_idvalue' => ['11122333']
      )
    end
  end
end
