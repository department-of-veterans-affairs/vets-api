# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::PoaUpdateVANotifyJob, type: :job do
  subject { described_class.new  }

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    headers = EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    headers['va_eauth_pnid'] = '796104437'
    headers
  end

  let(:org_poa_form_data) do
    {
      'data' => {
        'attributes' => {
          'serviceOrganization' => {
            'poaCode' => '072'
          },
          'signatures' => {
            'veteran' => 'helloWorld',
            'representative' => 'helloWorld'
          }
        }
      }
    }
  end

  let(:rep_poa_form_data) do
    {
      'data' => {
        'attributes' => {
          'representative' => {
            'poaCode' => '072',
            'firstName' => 'Myfn',
            'lastName' => 'Myln',
            'type' => 'ATTORNEY',
            'address' => {
              'numberAndStreet' => '123',
              'city' => 'city',
              'country' => 'US',
              'zipFirstFive' => '12345'
            }
          },
          'recordConsent' => true,
          'consentLimits' => []
        }
      }
    }
  end

  let(:clamant_poa_form_data) do
    {
      'data' => {
        'attributes' => {
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
      }
    }
  end

  let(:organization) do
    {
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
      state_code: nil,
      zip_code: '54321',
      zip_suffix: '9876',
      address_line1: nil,
      address_line2: nil,
      address_line3: nil
    }
  end

  let(:rep) do
    {
      representative_id: '12345',
      first_name: 'John',
      last_name: 'Doe',
      email: 'va.api.user+idme.007@gmail.com',
      phone: nil,
      zip_code: '54321',
      state_code: 'AZ'
    }
  end

  let(:vanotify_client) { instance_double(VaNotify::Service) }

  let(:settings_args) do
    [
      Settings.claims_api.vanotify.representative_template_id,
      Settings.claims_api.vanotify.service_organzation_template_id,
      Settings.claims_api.vanotify.services.lighthouse.api_key
    ]
  end

  let(:mock_relation) { instance_double('ActiveRecord::Relation', order: [rep], first: rep) }

  # rubocop:disable RSpec/SubjectStub
  before do
    Sidekiq::Job.clear_all
    Sidekiq::Testing.inline!
    allow(VaNotify::Service).to receive(:new).and_return(vanotify_client)
    allow(vanotify_client).to receive(:send_email)
    # allow(subject).to receive(:send_organization_notification)
    allow_any_instance_of(described_class).to receive(:send_representative_notification)
    allow(subject).to receive_messages(skip_notification_email?: false, 
                                      vanotify_service: vanotify_client, 
                                      find_org: :organization)
    allow(Veteran::Service::Representative).to receive(:where).and_return(mock_relation)
  end
  # rubocop:enable RSpec/SubjectStub

  context 'when the POA is updated to a representative' do
    # rubocop:disable RSpec/SubjectStub
    it 'correctly selects the representative template' do
      poa = create_rep_poa(rep_poa_form_data)
      expect(subject).to receive(:send_representative_notification).with(poa, rep)

      subject.perform(poa.id)
    end
    # rubocop:enable RSpec/SubjectStub

    context 'when the POA is filed by a dependent claimant' do
      # rubocop:disable RSpec/SubjectStub
      it 'correctly selects the representative template' do
        poa = create_rep_poa(clamant_poa_form_data)
        expect(subject).to receive(:send_representative_notification).with(poa, rep)

        subject.perform(poa.id)
      end
      # rubocop:enable RSpec/SubjectStub

      it 'sets the correct values in the email' do
        poa = create_rep_poa(clamant_poa_form_data)
        # allow(::Veteran::Service::Representative).to receive(:where)
        #   .and_return([rep])
        # allow(::Veteran::Service::Representative).to receive(:order)
        #   .and_return([rep])
        # allow([rep]).to receive(:first).and_return(rep)

        expected_params = {
          recipient_identifier: poa.source_data&.dig('icn'),
          personalisation: {
            first_name: poa.auth_headers['va_eauth_firstName'],
            rep_first_name: rep['first_name'],
            rep_last_name: rep['last_name'],
            representative_type: poa&.form_data&.dig('representative', 'type'),
            org_name: "083 - DISABLED AMERICAN VETERANS",
            address1: poa&.form_data.dig('representative', 'address', 'addressLine1'),
            address2: poa&.form_data.dig('representative', 'address', 'addressLine2'),
            city: poa&.form_data.dig('representative', 'address', 'city'),
            state: poa&.form_data.dig('representative', 'address', 'stateCode'),
            zip: rep_poa_form_data['zipFirstFive'],
            email: rep['email'],
            phone: nil
          }
        }

        expect(vanotify_client).to receive(:send_email)

        subject.perform(poa.id)
      end
    end
  end

  context 'when the POA is updated to a service organization' do
    # rubocop:disable RSpec/SubjectStub
    it 'correctly selects the service organization template' do
      poa = create_org_poa
      expect(subject).to receive(:send_organization_notification)

      subject.perform(poa.id)
    end
    # rubocop:enable RSpec/SubjectStub
  end

  private

  def create_rep_poa(form_data)
    poa = create(:power_of_attorney)
    poa.form_data = form_data
    poa.auth_headers = auth_headers
    poa.save
    poa
  end

  def create_org_poa
    poa = create(:power_of_attorney)
    poa.form_data = org_poa_form_data
    poa.auth_headers = auth_headers
    poa.save
    poa
  end

  def create_mock_lighthouse_service
    allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
    allow_any_instance_of(BGS::VetRecordWebService).to receive(:update_birls_record)
      .and_return({ return_code: 'BMOD0001' })
  end
end
