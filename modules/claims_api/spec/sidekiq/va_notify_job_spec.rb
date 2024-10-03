# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/common/exceptions/lighthouse/resource_not_found'

describe ClaimsApi::VANotifyJob, type: :job do
  subject { described_class.new  }

  let(:va_notify_org) do
    create(:organization, address_line1: '345 Sixth St.', address_line2: 'Suite 3',
                          zip_code: '12345', zip_suffix: '9876', city: 'Pensacola', state_code: 'FL')
  end

  let(:va_notify_rep) do
    create(:representative)
  end

  let(:rep_poa) do
    create(:power_of_attorney, form_data: va_notify_rep_poa_form_data, auth_headers: va_notify_auth_headers)
  end

  let(:rep_dep_poa) do
    create(:power_of_attorney, form_data: va_notify_dependent_form_data, auth_headers: va_notify_auth_headers)
  end

  let(:org_poa) do
    create(:power_of_attorney, form_data: va_notify_org_poa_form_data, auth_headers: va_notify_auth_headers)
  end

  let(:vanotify_client) { instance_double(VaNotify::Service) }

  let(:va_notify_rep_poa_form_data) do
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

  let(:va_notify_dependent_form_data) do
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
          'addressLine1' => '123 Fourth St.',
          'addressLine2' => 'Apt. 3',
          'addressLine3' => 'P.O Box 34',
          'city' => 'city',
          'stateCode' => 'OR',
          'country' => 'US',
          'zipCode' => '12345'
        }
      },
      'claimant' => {
        'claimantId' => '1111111V2222',
        'address' => {
          'addressLine1' => '456 Seventh St.',
          'addressLine2' => 'Apt. 3',
          'city' => 'city',
          'stateCode' => 'OR',
          'country' => 'US',
          'zipCode' => '12345'
        },
        'relationship' => 'spouse'
      }
    }
  end

  let(:va_notify_org_poa_form_data) do
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

  let(:va_notify_auth_headers) do
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

  describe '#perform' do
    context 'when the POA is updated to a representative' do
      describe '#send_representative_notification' do
        let(:ind_poa) { rep_poa }

        let(:ind_expected_params) do
          {
            recipient_identifier: rep_poa.auth_headers['va_notify_recipient_identifier'],
            personalisation: {
              first_name: rep_poa.auth_headers['va_eauth_firstName'],
              rep_first_name: va_notify_rep.first_name,
              rep_last_name: va_notify_rep.last_name,
              representative_type: va_notify_rep_poa_form_data['representative']['type'],
              address: "123 First St.\n Apt. 2",
              city: va_notify_rep_poa_form_data['representative']['address']['city'],
              state: va_notify_rep_poa_form_data['representative']['address']['stateCode'],
              zip: va_notify_rep_poa_form_data['representative']['address']['zipCode'],
              email: va_notify_rep.email,
              phone: va_notify_rep.phone_number
            },
            template_id: Settings.claims_api.vanotify.representative_template_id
          }
        end

        it 'formats the values correctly' do
          res = subject.send(:individual_accepted_email_contents, rep_poa, va_notify_rep)

          expect(res).to eq(ind_expected_params)
        end
      end
    end

    context 'when the POA is filed by a dependent claimant' do
      describe '#send_representative_notification for dependent' do
        let(:dependent_poa) { rep_dep_poa }

        let(:dependent_expected_params) do
          {
            recipient_identifier: rep_dep_poa.auth_headers['va_notify_recipient_identifier'],
            personalisation: {
              first_name: dependent_poa.auth_headers['va_eauth_firstName'],
              rep_first_name: va_notify_rep.first_name,
              rep_last_name: va_notify_rep.last_name,
              representative_type: va_notify_dependent_form_data['representative']['type'],
              address: "123 Fourth St.\n Apt. 3\n P.O Box 34",
              city: va_notify_dependent_form_data['representative']['address']['city'],
              state: va_notify_dependent_form_data['representative']['address']['stateCode'],
              zip: va_notify_dependent_form_data['representative']['address']['zipCode'],
              email: va_notify_rep.email,
              phone: va_notify_rep.phone_number
            },
            template_id: Settings.claims_api.vanotify.representative_template_id
          }
        end

        it 'formats the values correctly' do
          res = subject.send(:individual_accepted_email_contents, rep_dep_poa, va_notify_rep)

          expect(res).to eq(dependent_expected_params)
        end
      end
    end

    context 'when the POA is updated to a service organization' do
      describe '#organization_accepted_email_contents' do
        let(:organization_poa) { org_poa }

        let(:org_expected_params) do
          {
            recipient_identifier: org_poa.auth_headers['va_notify_recipient_identifier'],
            personalisation: {
              first_name: organization_poa.auth_headers['va_eauth_firstName'],
              org_name: va_notify_org.name,
              address: "345 Sixth St.\n Suite 3",
              city: va_notify_org.city,
              state: va_notify_org.state_code,
              zip: "#{va_notify_org.zip_code}-#{va_notify_org.zip_suffix}",
              phone: ''
            },
            template_id: Settings.claims_api.vanotify.service_organization_template_id
          }
        end

        it 'formats the values correctly' do
          res = subject.send(:organization_accepted_email_contents, organization_poa, va_notify_org)

          expect(res).to eq(org_expected_params)
        end
      end
    end
  end

  describe '#organization_filing?' do
    it 'properly selects the org template when the filing is 2122' do
      res = subject.send(:organization_filing?, org_poa.form_data)

      expect(res).not_to eq(nil)
    end

    it 'properly selects the rep template when the filing is 2122a' do
      res = subject.send(:organization_filing?, rep_poa.form_data)

      expect(res).to eq(nil)
    end

    it 'properly selects the rep template when the filing is 2122 for dependent claimant' do
      res = subject.send(:organization_filing?, rep_dep_poa.form_data)

      expect(res).to eq(nil)
    end
  end

  describe '#format_zip_values' do
    it 'formats two values correctly' do
      expected = '54321-9876'
      res = subject.send(:format_zip_values, '54321', '9876')

      expect(res).to eq(expected)
    end

    it 'formats just zip first 5 value correctly' do
      expected = '54321'
      res = subject.send(:format_zip_values, '54321', nil)

      expect(res).to eq(expected)
    end

    it 'formats just zip last 4 value correctly' do
      expected = '9876'
      res = subject.send(:format_zip_values, nil, '9876')

      expect(res).to eq(expected)
    end

    it 'formats no values correctly' do
      expected = ''
      res = subject.send(:format_zip_values, nil, nil)

      expect(res).to eq(expected)
    end
  end

  describe '#value_or_default_for_field' do
    it 'returns the values correctly' do
      expected = 'field value'
      res = subject.send(:value_or_default_for_field, 'field value')

      expect(res).to eq(expected)
    end

    # We need this because sending nil in the template results in an error
    it 'returns an empty string if nothing is present' do
      expected = ''
      res = subject.send(:value_or_default_for_field, nil)

      expect(res).to eq(expected)
    end
  end

  describe '#build_ind_poa_address' do
    it 'build the address correctly' do
      expected = "123 Fourth St.\n Apt. 3\n P.O Box 34"
      res = subject.send(:build_ind_poa_address, rep_dep_poa)

      expect(res).to eq(expected)
    end
  end

  describe '#build_org_address' do
    it 'build the address correctly' do
      expected = "345 Sixth St.\n Suite 3"
      res = subject.send(:build_org_address, va_notify_org)

      expect(res).to eq(expected)
    end
  end

  describe '#build_address' do
    it 'formats the values correctly with line1 & line2 & line3' do
      expected = "123 First St.\n Apt. 2\n Suite 5"
      res = subject.send(:build_address, '123 First St.', 'Apt. 2', 'Suite 5')

      expect(res).to eq(expected)
    end

    it 'formats the values correctly with line2 & line3' do
      expected = "Apt. 2\n Suite 5"
      res = subject.send(:build_address, nil, 'Apt. 2', 'Suite 5')

      expect(res).to eq(expected)
    end

    it 'formats the values correctly with line1 & line3' do
      expected = "123 First St.\n Suite 5"
      res = subject.send(:build_address, '123 First St.', nil, 'Suite 5')

      expect(res).to eq(expected)
    end
  end
end
