# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::VANotifyJob, type: :job do
  subject { described_class.new  }

  let(:org) do
    Veteran::Service::Organization.create!(
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
      address_line3: nil
    )
  end

  let(:rep) do
    create(:representative, representative_id: '12345', first_name: 'Bob', last_name: 'Law',
                            email: 'bob.law,test@gmail.com', poa_codes: ['ABC'], user_types: ['claim_agents'],
                            phone: '123-456-7890', address_line1: '321 First St.', zip_code: '54321',
                            state_code: 'AZ', phone_number: '000-867-5309')
  end

  let(:vanotify_client) { instance_double(VaNotify::Service) }

  # rubocop:disable RSpec/SubjectStub
  before do
    Sidekiq::Job.clear_all
    Sidekiq::Testing.inline!
    allow(subject).to receive_messages(skip_notification_email?: false,
                                       vanotify_service: vanotify_client,
                                       find_org: :organization)
  end
  # rubocop:enable RSpec/SubjectStub

  context 'when the POA is updated to a representative' do
    # rubocop:disable RSpec/SubjectStub
    it 'correctly selects the representative template' do
      ind_poa = create_poa(rep_poa_form_data)
      expect(subject).to receive(:send_representative_notification).with(ind_poa, rep)

      subject.perform(ind_poa.id, ind_poa.source_data&.dig('icn'), rep)
    end
    # rubocop:enable RSpec/SubjectStub

    describe '#send_representative_notification' do
      let(:ind_poa) { create_poa(rep_poa_form_data) }

      let(:ind_expected_params) do
        {
          recipient_identifier: ind_poa.source_data&.dig('icn'),
          personalisation: {
            first_name: ind_poa.auth_headers['va_eauth_firstName'],
            rep_first_name: rep.first_name,
            rep_last_name: rep.last_name,
            representative_type: rep_poa_form_data['representative']['type'],
            address1: rep_poa_form_data['representative']['address']['addressLine1'],
            city: rep_poa_form_data['representative']['address']['city'],
            state: rep_poa_form_data['representative']['address']['stateCode'],
            zip: rep_poa_form_data['representative']['address']['zipCode'],
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
  end

  context 'when the POA is filed by a dependent claimant' do
    # rubocop:disable RSpec/SubjectStub
    it 'correctly selects the representative template' do
      dependent_poa = create_poa(dependent_form_data)
      expect(subject).to receive(:send_representative_notification).with(dependent_poa, rep)

      subject.perform(dependent_poa.id, dependent_poa.source_data&.dig('icn'), rep)
    end
    # rubocop:enable RSpec/SubjectStub

    describe '#send_representative_notification for dependent' do
      let(:dependent_poa) { create_poa(dependent_form_data) }

      let(:dependent_expected_params) do
        {
          recipient_identifier: dependent_poa.source_data&.dig('icn'),
          personalisation: {
            first_name: dependent_poa.auth_headers['va_eauth_firstName'],
            rep_first_name: rep.first_name,
            rep_last_name: rep.last_name,
            representative_type: dependent_form_data['representative']['type'],
            address1: dependent_form_data['representative']['address']['addressLine1'],
            city: dependent_form_data['representative']['address']['city'],
            state: dependent_form_data['representative']['address']['stateCode'],
            zip: dependent_form_data['representative']['address']['zipCode'],
            email: rep.email,
            phone: rep.phone_number
          },
          template_id: Settings.claims_api.vanotify.representative_template_id # not sure how to get this faked
        }
      end

      it 'formats the values correctly' do
        subject.instance_variable_set('@icn_for_vanotify', dependent_poa.source_data&.dig('icn'))
        res = subject.send(:individual_accepted_email_contents, dependent_poa, rep)

        expect(res).to eq(dependent_expected_params)
      end
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

    describe '#organization_accepted_email_contents' do
      let(:org_poa) { create_org_poa }
      let(:org_expected_params) do
        {
          recipient_identifier: org_poa.source_data&.dig('icn'),
          personalisation: {
            first_name: org_poa.auth_headers['va_eauth_firstName'],
            org_name: org.name,
            address1: org.address_line1,
            address2: '',
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

  def create_poa(poa_form_data)
    poa = create(:power_of_attorney)
    poa.form_data = poa_form_data
    poa.auth_headers = auth_headers
    poa.save!
    poa
  end

  def rep_poa_form_data
    {
      'representative' => {
        'poaCode' => '072',
        'firstName' => 'Myfn',
        'lastName' => 'Myln',
        'type' => 'ATTORNEY',
        'address' => {
          'addressLine1' => '123',
          'city' => 'North Beach',
          'stateCode' => 'OR',
          'country' => 'US',
          'zipCode' => '12345'
        }
      },
      'recordConsent' => true,
      'consentLimits' => []
    }
  end

  # rubocop:disable Metrics/MethodLength
  def dependent_form_data
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
  # rubocop:enable Metrics/MethodLength

  def create_org_poa
    poa = create(:power_of_attorney)
    poa.form_data = org_poa_form_data
    poa.auth_headers = auth_headers
    poa.save
    poa
  end

  def org_poa_form_data
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

  def auth_headers
    {
      'va_eauth_firstName' => 'Jeffery',
      'va_eauth_lastName' => 'Hayes',
      'va_eauth_dodedipnid' => '1005648021',
      'va_eauth_birlsfilenumber' => '123456',
      'va_eauth_pid' => '600043202',
      'va_eauth_pnid' => '796131729'
    }
  end

  def dependent_auth_headers
    {
      'va_eauth_firstName' => 'John',
      'va_eauth_lastName' => 'Dependent',
      'va_eauth_dodedipnid' => '1005648022',
      'va_eauth_birlsfilenumber' => '123456789',
      'va_eauth_pid' => '600043233',
      'va_eauth_pnid' => '796131730'
    }
  end
end
