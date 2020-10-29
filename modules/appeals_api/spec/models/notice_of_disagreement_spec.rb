# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::NoticeOfDisagreement, type: :model do
  include FixtureHelpers

  let(:notice_of_disagreement) { described_class.create form_data: form_data, auth_headers: auth_headers }

  let(:auth_headers) { default_auth_headers }
  let(:form_data) { default_form_data }

  let(:default_auth_headers) { fixture_as_json 'valid_10182_headers.json' }
  let(:default_form_data) { fixture_as_json 'valid_10182.json' }

  describe '.create' do
    it('has no errors') do
      expect(notice_of_disagreement.errors).to be_empty
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

      let(:auth_headers) do
        default_auth_headers.except(
          'X-VA-Claimant-First-Name',
          'X-VA-Claimant-Middle-Initial',
          'X-VA-Claimant-Last-Name',
          'X-VA-Claimant-Birth-Date'
        )
      end

      it('has errors') do
        expect(notice_of_disagreement.errors.count).to be 1
        expect(notice_of_disagreement.errors.full_messages.first).to include 'addressLine1'
      end
    end
  end

  describe '10182 headers schema' do
    context 'missing veteran last name' do
      let(:auth_headers) { default_auth_headers.except('X-VA-Veteran-Last-Name') }

      it('has errors') do
        expect(notice_of_disagreement.errors.count).to be 1
        expect(notice_of_disagreement.errors.full_messages.first).to include 'Veteran-Last-Name'
      end
    end
  end
end
