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
end
