# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::VANotifyJob, type: :job do
  subject { described_class.new  }

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:org_poa_form_data) do
    {
        'serviceOrganization' => {
          'poaCode' => '083'
        },
        'signatures' => {
          'veteran' => 'helloWorld',
          'representative' => 'helloWorld'
        }
    }
  end
  let(:rep_poa_form_data) do
    {
      'representative' => {
        'poaCode' => '072',
        'firstName' => 'Myfn',
        'lastName' => 'Myln',
        'type' => 'ATTORNEY',
        'address' => {
          'addressLine1' => '123',
          'city' => 'North Beach',
          "stateCode" => 'OR',
          'country' => 'US',
          'zipFirstFive' => '12345'
        }
      },
      'recordConsent' => true,
      'consentLimits' => []
    }
  end
  let(:clamant_poa_form_data) do
    {
      'veteran' => {
        'address' => {
          'addressLine1' => '123',
          'city' => 'city',
          'stateCode' => 'OR',
          'country' => 'US',
          'zipCode' => '12345'
        }
      },
      'representative' => {
        'poaCode' => '067',
        'registrationNumber' => '999999999999',
        'type' => 'ATTORNEY',
        'address' => {
          'addressLine1' => '123',
          'city' => 'city',
          'stateCode' => 'OR',
          'country' => 'US',
          'zipCode' => '12345'
        }
      },
      'claimant' => {
        'claimantId' => '1013062086V794840',
        'address' => {
          'addressLine1' => '123',
          'city' => 'city',
          'stateCode' => 'OR',
          'country' => 'US',
          'zipCode' => '12345'
        },
        'relationship' => 'spouse'
      }
    }
  end
  let(:auth_headers) do
    {
      "va_eauth_firstName"=>"Jeffery", 
      "va_eauth_lastName"=>"Hayes", 
      "va_eauth_dodedipnid"=>"1005648021", 
      "va_eauth_birlsfilenumber"=>"123456", 
      "va_eauth_pid"=>"600043202", 
      "va_eauth_pnid"=>"796131729", 
    }
  end
  let(:org) do
    instance_double("Veteran::Service::Organization", 
      poa: '083',
      name: '083 - DISABLED AMERICAN VETERANS',
      phone: '920-867-5309',
      state: 'TN',
      created_at: Time.zone.now,
      updated_at: Time.zone.now,
      address_type: nil,
      city: 'Memphis',
      country_code_iso3: nil,
      country_name: nil,
      county_name: nil,
      county_code: nil,
      international_postal_code: nil,
      province: nil,
      state_code: 'TN',
      zip_code: '54321',
      zip_suffix: '9876',
      address_line1: '345 Sixth St.',
      address_line2: nil,
      address_line3: nil)
  end
  let(:rep) do
    instance_double("Veteran::Service::Representative", 
                  representative_id: '12345',
                  first_name: 'John',
                  last_name: 'Doe',
                  email: 'va.api.user+idme.007@gmail.com',
                  phone: nil,
                  user_types: ['claim_agents'], # we want the form to have the new rep's type so this might not match
                  address_line1: '321 First St.',
                  zip_code: '54321',
                  state_code: 'AZ',
                  phone_number: '000-867-5309')
  end
  let(:vanotify_client) { instance_double(VaNotify::Service) }
  let(:mock_relation) { instance_double('ActiveRecord::Relation', order: [rep], first: rep) }

  # rubocop:disable RSpec/SubjectStub
  before do
    Sidekiq::Job.clear_all
    Sidekiq::Testing.inline!
    allow(subject).to receive_messages(skip_notification_email?: false, 
                                      vanotify_service: vanotify_client, 
                                      find_org: :organization)
    allow(Veteran::Service::Representative).to receive(:where).and_return(mock_relation)
  end
  # rubocop:enable RSpec/SubjectStub

  context 'when the POA is updated to a representative' do
    # rubocop:disable RSpec/SubjectStub
    it 'correctly selects the representative template' do
      ind_poa = create_rep_poa
      expect(subject).to receive(:send_representative_notification).with(ind_poa, rep)

      subject.perform(ind_poa.id, ind_poa.source_data&.dig('icn'), rep)
    end
    # rubocop:enable RSpec/SubjectStub

    context '#send_representative_notification' do
      let(:ind_poa) { create_rep_poa }
      let(:ind_expected_params) do
        {
          recipient_identifier: ind_poa.source_data&.dig('icn'),
          personalisation: {
            first_name: ind_poa.auth_headers['va_eauth_firstName'],
            rep_first_name: rep.first_name,
            rep_last_name: rep.last_name,
            representative_type: rep_poa_form_data['representative']['type'],
            address1: rep_poa_form_data['representative']['address']['addressLine1'],
            address2: '',
            city: rep_poa_form_data['representative']['address']['city'],
            state: rep_poa_form_data['representative']['address']['stateCode'],
            zip: rep_poa_form_data['representative']['address']['zipFirstFive'],
            email: rep.email,
            phone: rep.phone_number
          },
          template_id: Settings.claims_api.vanotify.representative_template_id # not sure how to get this faked
        }
      end

      it 'formats the values correctly' do
        subject.instance_variable_set('@icn_for_vanotify', ind_poa.source_data&.dig('icn'))
        res = subject.send(:individual_accepted_email_contents, ind_poa, rep)

        expect(res).to eq(ind_expected_params)
      end
    end

    context 'when the POA is filed by a dependent claimant' do
      # rubocop:disable RSpec/SubjectStub
      it 'correctly selects the representative template' do
        ind_poa = create_rep_poa
        expect(subject).to receive(:send_representative_notification).with(ind_poa, rep)

        subject.perform(ind_poa.id, ind_poa.source_data&.dig('icn'), rep)
      end
      # rubocop:enable RSpec/SubjectStub
    end
  end

  context 'when the POA is updated to a service organization' do
    # rubocop:disable RSpec/SubjectStub
    it 'correctly selects the service organization template' do
      org_poa = create_org_poa
      expect(subject).to receive(:send_organization_notification)

      subject.perform(org_poa.id, org_poa.source_data&.dig('icn'), rep)
    end
    # rubocop:enable RSpec/SubjectStub

    context '#organization_accepted_email_contents' do
      let(:org_poa) { create_org_poa }
      let(:org_expected_params) do
        {
          recipient_identifier: org_poa.source_data&.dig('icn'),
          personalisation: {
            first_name: org_poa.auth_headers['va_eauth_firstName'],
            org_name: org.name,
            address1: org.address_line1,
            address2: "",
            city: org.city,
            state: org.state_code,
            zip: "#{org.zip_code}-#{org.zip_suffix}",
            phone: org.phone
          },
          template_id: Settings.claims_api.vanotify.service_organization_template_id
        }
      end

      it 'formats the values correctly' do
        subject.instance_variable_set('@icn_for_vanotify', org_poa.source_data&.dig('icn'))
        res = subject.send(:organization_accepted_email_contents, org_poa, org)

        expect(res).to eq(org_expected_params)
      end
    end
  end

  private

  def create_rep_poa
    poa = create(:power_of_attorney)
    poa.form_data = rep_poa_form_data
    poa.auth_headers = auth_headers
    poa.save!
    poa
  end

  def create_org_poa
    poa = create(:power_of_attorney)
    poa.form_data = org_poa_form_data
    poa.auth_headers = auth_headers
    poa.save
    poa
  end

  # def create_mock_lighthouse_service
  #   allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
  #   allow_any_instance_of(BGS::VetRecordWebService).to receive(:update_birls_record)
  #     .and_return({ return_code: 'BMOD0001' })
  # end
end
