# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::UserInfo do
  shared_examples 'valid GCID code' do
    let(:gcids) { example_gcid }

    it 'is valid' do
      expect(user_info).to be_valid
    end
  end

  describe 'attributes' do
    subject(:user_info) { described_class.new(attributes) }

    let(:attributes) do
      {
        sub: 'some-sub',
        ial: 'some-ial',
        aal: 'some-aal',
        csp_type: 'some-csp-type',
        csp_uuid: 'some-csp-uuid',
        email: 'some-email',
        first_name: 'some-first-name',
        last_name: 'some-last-name',
        full_name: 'some-full-name',
        birth_date: 'some-birth-date',
        ssn: 'some-ssn',
        gender: 'some-gender',
        address_street1: 'some-street1',
        address_street2: 'some-street2',
        address_city: 'some-city',
        address_state: 'some-state',
        address_country: 'some-country',
        address_postal_code: 'some-postal-code',
        phone_number: 'some-phone-number',
        person_types: 'some-person-types',
        icn: 'some-icn',
        sec_id: 'some-sec',
        edipi: 'some-edipi',
        mhv_ien: 'some-mhv-ien',
        npi_id: 'some-npi-id',
        cerner_id: 'some-cerner-id',
        corp_id: 'some-corp-id',
        birls: 'some-birls',
        gcids:
      }
    end

    context 'validations' do
      subject(:user_info) { described_class.new(attributes) }

      let(:attributes) do
        {
          gcids:
        }
      end

      context 'when gcids are valid' do
        let(:gcids) do
          '1000123456V123456^NI^200M^USVHA^P|12345^PI^516^USVHA^PCE|2^PI^553^USVHA^PCE'
        end

        it 'is valid' do
          expect(user_info).to be_valid
        end
      end

      context 'when gcids contain each valid GCID type code' do
        context 'ICN code' do
          let(:example_gcid) { '1000123456V123456^NI^200M^USVHA^P' }

          it_behaves_like 'valid GCID code'
        end

        context 'SEC ID code' do
          let(:example_gcid) { '12345^PI^200PROV^USVHA^P' }

          it_behaves_like 'valid GCID code'
        end

        context 'EDIPI code' do
          let(:example_gcid) { '1234567890^NI^200DOD^USDOD^P' }

          it_behaves_like 'valid GCID code'
        end

        context 'MHV IEN code' do
          let(:example_gcid) { '12345^PI^200MHV^USVHA^P' }

          it_behaves_like 'valid GCID code'
        end

        context 'NPI ID code' do
          let(:example_gcid) { '1234567890^NI^200ENPI^USVHA^P' }

          it_behaves_like 'valid GCID code'
        end

        context 'VHIC ID code' do
          let(:example_gcid) { '12345^PI^200VHIC^USVHA^P' }

          it_behaves_like 'valid GCID code'
        end

        context 'NWHIN ID code' do
          let(:example_gcid) { '12345^PI^200NWS^USVHA^P' }

          it_behaves_like 'valid GCID code'
        end

        context 'Cerner ID code' do
          let(:example_gcid) { '12345^PI^200CRNR^USVHA^P' }

          it_behaves_like 'valid GCID code'
        end

        context 'Corp ID code' do
          let(:example_gcid) { '12345^PI^200CORP^USVHA^P' }

          it_behaves_like 'valid GCID code'
        end

        context 'BIRLS ID code' do
          let(:example_gcid) { '12345^PI^200BRLS^USVHA^P' }

          it_behaves_like 'valid GCID code'
        end

        context 'Salesforce ID code' do
          let(:example_gcid) { '12345^PI^200DSLF^USVHA^P' }

          it_behaves_like 'valid GCID code'
        end

        context 'USAccess PIV code' do
          let(:example_gcid) { '12345^PI^200PUSA^USVHA^P' }

          it_behaves_like 'valid GCID code'
        end

        context 'PIV ID code' do
          let(:example_gcid) { '12345^PI^200PIV^USVHA^P' }

          it_behaves_like 'valid GCID code'
        end

        context 'VA Active Directory ID code' do
          let(:example_gcid) { '12345^PI^200AD^USVHA^P' }

          it_behaves_like 'valid GCID code'
        end

        context 'USA Staff ID code' do
          let(:example_gcid) { '12345^PI^200USAF^USVHA^P' }

          it_behaves_like 'valid GCID code'
        end

        describe 'numeric GCID codes' do
          let(:gcids) { '12345^PI^516^USVHA^PCE' }

          it 'is valid' do
            expect(user_info).to be_valid
          end
        end

        describe 'multiple valid GCID codes' do
          let(:gcids) do
            '1000123456V123456^NI^200M^USVHA^P|12345^PI^200PROV^USVHA^P|1234567890^NI^200DOD^USDOD^P'
          end

          it 'is valid' do
            expect(user_info).to be_valid
          end
        end

        describe 'mixed named and numeric GCID codes' do
          let(:gcids) do
            '1000123456V123456^NI^200M^USVHA^P|12345^PI^516^USVHA^PCE|2^PI^553^USVHA^PCE'
          end

          it 'is valid' do
            expect(user_info).to be_valid
          end
        end
      end

      context 'when gcids are invalid' do
        let(:expected_error_message) { 'contains non-approved gcids' }

        context 'when gcids contain an invalid code' do
          let(:gcids) do
            '1000123456V123456^NI^200BAD^USVHA^P|1000123456V123456^NI^200INVALID^USVHA^P'
          end

          it 'is not valid' do
            expect(user_info).not_to be_valid
            expect(user_info.errors[:gcids]).to include(expected_error_message)
          end
        end

        context 'when gcids contain mixed valid and invalid codes' do
          let(:gcids) do
            '1000123456V123456^NI^200M^USVHA^P|12345^PI^INVALID^USVHA^P|2^PI^553^USVHA^PCE'
          end

          it 'is not valid' do
            expect(user_info).not_to be_valid
            expect(user_info.errors[:gcids]).to include(expected_error_message)
          end
        end

        context 'when gcids is blank' do
          let(:gcids) { '' }

          it 'is valid (allows blank gcids)' do
            expect(user_info).to be_valid
          end
        end

        context 'when gcids is nil' do
          let(:gcids) { nil }

          it 'is valid (allows nil gcids)' do
            expect(user_info).to be_valid
          end
        end

        context 'when gcids is not a string' do
          let(:gcids) { %w[200M 200PROV] }

          it 'is not valid' do
            expect(user_info).not_to be_valid
            expect(user_info.errors[:gcids]).to include(expected_error_message)
          end
        end

        context 'when gcids contains segments with missing code' do
          let(:gcids) { '1000123456V123456^NI^^USVHA^P' }

          it 'is not valid' do
            expect(user_info).not_to be_valid
            expect(user_info.errors[:gcids]).to include(expected_error_message)
          end
        end

        context 'when gcids contains malformed segments' do
          let(:gcids) { '1000123456V123456' }

          it 'is not valid' do
            expect(user_info).not_to be_valid
            expect(user_info.errors[:gcids]).to include(expected_error_message)
          end
        end
      end
    end
  end
end
