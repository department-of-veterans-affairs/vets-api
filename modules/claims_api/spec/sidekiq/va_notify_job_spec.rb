# frozen_string_literal: true

require 'rails_helper'

describe ClaimsApi::VANotifyJob, type: :job do
  subject { described_class.new  }

  let(:va_notify_org) do
    create(:organization)
  end

  let(:va_notify_rep) do
    create(:representative)
  end

  let(:rep_poa) do
    create(:power_of_attorney, form_data: va_notify_rep_poa_form_data, auth_headers: va_notify_auth_headers)
  end

  let(:vanotify_client) { instance_double(VaNotify::Service) }

  before do
    # Sidekiq::Job.clear_all
    # Sidekiq::Testing.inline!
    # rubocop:disable RSpec/SubjectStub
    allow(subject).to receive_messages(skip_notification_email?: false, vanotify_service: vanotify_client,
                                       find_org: :va_notify_org)
    # rubocop:enable RSpec/SubjectStub
  end

  # context 'when the POA is updated to a representative' do
  # rubocop:disable RSpec/SubjectStub
  it 'correctly selects the representative template' do
    allow(ClaimsApi::PowerOfAttorney).to receive(:find).with(rep_poa.id).and_return(rep_poa)

    expect(subject).to receive(:send_representative_notification).with(rep_poa, va_notify_rep)

    subject.perform(rep_poa.id, va_notify_rep)
  end
  # rubocop:enable RSpec/SubjectStub

  # describe '#send_representative_notification' do
  #   let(:ind_poa) { rep_poa }

  #   let(:ind_expected_params) do
  #     {
  #       recipient_identifier: ind_poa.source_data&.dig('icn'),
  #       personalisation: {
  #         first_name: rep_poa.auth_headers['va_eauth_firstName'],
  #         rep_first_name: rep.first_name,
  #         rep_last_name: rep.last_name,
  #         representative_type: va_notify_rep_poa_form_data['representative']['type'],
  #         address: "123 First St.\n Apt. 2",
  #         city: va_notify_rep_poa_form_data['representative']['address']['city'],
  #         state: va_notify_rep_poa_form_data['representative']['address']['stateCode'],
  #         zip: va_notify_rep_poa_form_data['representative']['address']['zipCode'],
  #         email: va_notify_rep.email,
  #         phone: va_notify_rep.phone_number
  #       },
  #       template_id: Settings.claims_api.vanotify.representative_template_id
  #     }
  #   end

  #   it 'formats the values correctly' do
  #     subject.instance_variable_set('@icn_for_vanotify', rep_poa.source_data&.dig('icn'))
  #     res = subject.send(:individual_accepted_email_contents, rep_poa, rep)

  #     expect(res).to eq(ind_expected_params)
  #   end
  # end
  # end

  # context 'when the POA is filed by a dependent claimant' do
  # it 'correctly selects the representative template' do
  #   dependent_poa = va_notify_create_poa(dependent_form_data)
  #   expect(subject).to receive(:send_representative_notification).with(dependent_poa, rep)

  #   subject.perform(dependent_poa.id, dependent_poa.source_data&.dig('icn'), rep)
  # end
  # describe '#send_representative_notification for dependent' do
  #   let(:dependent_poa) { va_notify_create_poa(dependent_form_data) }

  #   let(:dependent_expected_params) do
  #     {
  #       recipient_identifier: dependent_poa.source_data&.dig('icn'),
  #       personalisation: {
  #         first_name: dependent_poa.auth_headers['va_eauth_firstName'],
  #         rep_first_name: rep.first_name,
  #         rep_last_name: rep.last_name,
  #         representative_type: dependent_form_data['representative']['type'],
  #         address: dependent_form_data['representative']['address']['addressLine1'],
  #         city: dependent_form_data['representative']['address']['city'],
  #         state: dependent_form_data['representative']['address']['stateCode'],
  #         zip: dependent_form_data['representative']['address']['zipCode'],
  #         email: rep.email,
  #         phone: rep.phone_number
  #       },
  #       template_id: Settings.claims_api.vanotify.representative_template_id # not sure how to get this faked
  #     }
  #   end

  #   it 'formats the values correctly' do
  #     subject.instance_variable_set('@icn_for_vanotify', dependent_poa.source_data&.dig('icn'))
  #     res = subject.send(:individual_accepted_email_contents, dependent_poa, rep)

  #     expect(res).to eq(dependent_expected_params)
  #   end
  # end
  # end

  # context 'when the POA is updated to a service organization' do
  # it 'correctly selects the service organization template' do
  #   org_poa = vanotify_create_org_poa
  #   expect(subject).to receive(:send_organization_notification)

  #   subject.perform(org_poa.id, org_poa.source_data&.dig('icn'), rep)
  # end
  # describe '#organization_accepted_email_contents' do
  #   let(:org_poa) { vanotify_create_org_poa }
  #   let(:org_expected_params) do
  #     {
  #       recipient_identifier: org_poa.source_data&.dig('icn'),
  #       personalisation: {
  #         first_name: org_poa.auth_headers['va_eauth_firstName'],
  #         org_name: org.name,
  #         address: "345 Sixth St.\n Suite 3",
  #         city: org.city,
  #         state: org.state_code,
  #         zip: "#{org.zip_code}-#{org.zip_suffix}",
  #         phone: org.phone
  #       },
  #       template_id: Settings.claims_api.vanotify.service_organization_template_id
  #     }
  #   end

  #   it 'formats the values correctly' do
  #     subject.instance_variable_set('@icn_for_vanotify', org_poa.source_data&.dig('icn'))
  #     res = subject.send(:organization_accepted_email_contents, org_poa, org)

  #     expect(res).to eq(org_expected_params)
  #   end
  # end
  # end

  private

  # def va_notify_create_poa(poa_form_data)
  #   create(:power_of_attorney, form_data: poa_form_data, auth_headers: va_notify_auth_headers)
  # end

  def va_notify_rep_poa_form_data
    {
      'representative' => {
        'poaCode' => '072',
        'firstName' => 'Myfn',
        'lastName' => 'Myln',
        'type' => 'ATTORNEY',
        'address' => {
          'addressLine1' => '123 First St.',
          'addressLine2' => 'Apt. 2',
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

  # def va_notify_dependent_form_data
  #   {
  #     'veteran' => {
  #       'address' => {
  #         'addressLine1' => '123',
  #         'city' => 'city',
  #         'stateCode' => 'OR',
  #         'country' => 'US',
  #         'zipCode' => '12345'
  #       }
  #     },
  #     'representative' => {
  #       'poaCode' => '067',
  #       'registrationNumber' => '999999999999',
  #       'type' => 'ATTORNEY',
  #       'address' => {
  #         'addressLine1' => '123',
  #         'city' => 'city',
  #         'stateCode' => 'OR',
  #         'country' => 'US',
  #         'zipCode' => '12345'
  #       }
  #     },
  #     'claimant' => {
  #       'claimantId' => '1013062086V794840',
  #       'address' => {
  #         'addressLine1' => '123',
  #         'city' => 'city',
  #         'stateCode' => 'OR',
  #         'country' => 'US',
  #         'zipCode' => '12345'
  #       },
  #       'relationship' => 'spouse'
  #     }
  #   }
  # end
  # def vanotify_create_org_poa
  #   create(:power_of_attorney, form_data: va_notify_org_poa_form_data, auth_headers: va_notify_auth_headers)
  # end

  # def va_notify_org_poa_form_data
  #   {
  #     'serviceOrganization' => {
  #       'poaCode' => '083'
  #     },
  #     'signatures' => {
  #       'veteran' => 'helloWorld',
  #       'representative' => 'helloWorld'
  #     }
  #   }
  # end

  def va_notify_auth_headers
    {
      'va_eauth_firstName' => 'Jeffery',
      'va_eauth_lastName' => 'Hayes',
      'va_eauth_dodedipnid' => '1005648021',
      'va_eauth_birlsfilenumber' => '123456',
      'va_eauth_pid' => '600043202',
      'va_eauth_pnid' => '796131729',
      'va_notify_recipient_identifier' => '1111111V2222'
    }
  end
end
