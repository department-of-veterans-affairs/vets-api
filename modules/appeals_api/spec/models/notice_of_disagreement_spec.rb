# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::NoticeOfDisagreement, type: :model do
  include FixtureHelpers

  let(:notice_of_disagreement) { build(:notice_of_disagreement, form_data: form_data, auth_headers: auth_headers) }

  let(:auth_headers) { default_auth_headers }
  let(:form_data) { default_form_data }

  let(:default_auth_headers) { fixture_as_json 'valid_10182_headers.json' }
  let(:default_form_data) { fixture_as_json 'valid_10182.json' }

  describe '.build' do
    before { notice_of_disagreement.valid? }

    it('has no errors') do
      expect(notice_of_disagreement.errors).to be_empty
    end
  end

  describe 'validations' do
    describe '#validate_that_at_least_one_set_of_contact_info_is_present' do
      context 'when veteran is present and claimant is not' do
        before { form_data['data']['attributes'].delete('claimant') }

        let(:auth_headers) { headers_without_claimant(default_auth_headers) }

        it do
          expect(notice_of_disagreement.errors).to be_empty
        end
      end

      context 'when claimant is present and veteran is not' do
        before { form_data['data']['attributes'].delete('veteran') }

        it do
          expect(notice_of_disagreement.errors).to be_empty
        end
      end

      context 'when claimant and veteran are not present' do
        let(:auth_headers) { headers_without_claimant(default_auth_headers) }

        before do
          form_data['data']['attributes'].delete('claimant')
          form_data['data']['attributes'].delete('veteran')
          notice_of_disagreement.valid?
        end

        it do
          expect(notice_of_disagreement.errors.count).to be 1
          expect(notice_of_disagreement.errors.full_messages.first).to eq('Form data at least one must be included: ' \
"'/data/attributes/veteran', '/data/attributes/claimant'")
        end
      end
    end

    describe '#validate_claimant_properly_included_or_absent' do
      context 'when all claimant fields are present' do
        it { expect(notice_of_disagreement.errors).to be_empty }
      end

      context 'when claimant name is missing' do
        let(:auth_headers) do
          default_auth_headers.except('X-VA-Claimant-First-Name', 'X-VA-Claimant-Middle-Initial',
                                      'X-VA-Claimant-Last-Name')
        end

        before { notice_of_disagreement.valid? }

        it do
          expect(notice_of_disagreement.errors.count).to be 1
          expect(notice_of_disagreement.errors.full_messages.first).to eq('Auth headers if any claimant info is' \
' present, claimant name must also be present')
        end
      end

      context 'when claimant birth date is missing' do
        let(:auth_headers) { default_auth_headers.except('X-VA-Claimant-Birth-Date') }

        before { notice_of_disagreement.valid? }

        it do
          expect(notice_of_disagreement.errors.count).to be 1
          expect(notice_of_disagreement.errors.full_messages.first).to eq('Auth headers if any claimant info is' \
' present, claimant birth date must also be present')
        end
      end

      context 'when claimant contact info is missing' do
        before do
          form_data['data']['attributes'].delete('claimant')
          notice_of_disagreement.valid?
        end

        it do
          expect(notice_of_disagreement.errors.count).to be 1
          expect(notice_of_disagreement.errors.full_messages.first).to eq('Form data if any claimant info is present,' \
' claimant contact info (data/attributes/claimant) must also be present')
        end
      end
    end
  end

  describe '10182 schema' do
    context 'missing addressLine1' do
      let(:form_data) do
        {
          'data' => {
            'type' => default_form_data['data']['type'],
            'attributes' => {
              'boardReviewOption' => default_form_data['data']['attributes']['boardReviewOption'],
              'socOptIn' => default_form_data['data']['attributes']['socOptIn'],
              'veteran' => {
                'homeless' => default_form_data['data']['attributes']['veteran']['homeless'],
                'address' => default_form_data['data']['attributes']['veteran']['address'].except('addressLine1'),
                'phone' => default_form_data['data']['attributes']['veteran']['phone'],
                'emailAddressText' => default_form_data['data']['attributes']['veteran']['emailAddressText']
              }
            }
          },
          'included' => default_form_data['included']
        }
      end

      let(:auth_headers) { headers_without_claimant(default_auth_headers) }

      before { notice_of_disagreement.valid? }

      it('has errors') do
        expect(notice_of_disagreement.errors.count).to be 1
        expect(notice_of_disagreement.errors.full_messages.first).to include 'addressLine1'
      end
    end
  end

  describe '10182 headers schema' do
    context 'missing veteran last name' do
      let(:auth_headers) { default_auth_headers.except('X-VA-Veteran-Last-Name') }

      before { notice_of_disagreement.valid? }

      it('has errors') do
        expect(notice_of_disagreement.errors.count).to be 1
        expect(notice_of_disagreement.errors.full_messages.first).to include 'Veteran-Last-Name'
      end
    end
  end

  describe '.date_from_string' do
    context 'when the string is in the correct format' do
      it { expect(described_class.date_from_string('2005-12-24')).to eq(Date.parse('2005-12-24')) }
    end

    context 'when the string is in the incorrect format' do
      it 'returns nil' do
        expect(described_class.date_from_string('200-12-24')).to be_nil
        expect(described_class.date_from_string('12-24-2005')).to be_nil
        expect(described_class.date_from_string('2005')).to be_nil
        expect(described_class.date_from_string('abc')).to be_nil
      end
    end
  end

  describe '#claimant_name' do
    context 'when claimant headers are present' do
      it do
        expect(notice_of_disagreement.claimant_name).to eq(
          "#{default_auth_headers['X-VA-Claimant-First-Name']} " \
          "#{default_auth_headers['X-VA-Claimant-Middle-Initial']} "\
          "#{default_auth_headers['X-VA-Claimant-Last-Name']}"
        )
      end
    end

    context 'when claimant headers are not present' do
      let(:auth_headers) do
        default_auth_headers.except('X-VA-Claimant-First-Name', 'X-VA-Claimant-Middle-Initial',
                                    'X-VA-Claimant-Last-Name')
      end

      it { expect(notice_of_disagreement.claimant_name).to be_empty }
    end
  end

  describe '#claimant_birth_date' do
    context 'when claimant headers are present' do
      it { expect(notice_of_disagreement.claimant_birth_date).to eq(Date.parse('1970-01-01')) }
    end

    context 'when claimant headers are not present' do
      let(:auth_headers) do
        default_auth_headers.except('X-VA-Claimant-Birth-Date')
      end

      it { expect(notice_of_disagreement.claimant_birth_date).to be_nil }
    end
  end

  describe '#consumer_name' do
    it { expect(notice_of_disagreement.consumer_name).to eq('va.gov') }
  end

  private

  def headers_without_claimant(default_auth_headers)
    default_auth_headers.except(
      'X-VA-Claimant-First-Name',
      'X-VA-Claimant-Middle-Initial',
      'X-VA-Claimant-Last-Name',
      'X-VA-Claimant-Birth-Date'
    )
  end
end
