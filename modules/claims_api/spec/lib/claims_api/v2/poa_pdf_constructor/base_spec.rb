# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v2/poa_pdf_constructor/base'
require_relative '../../shared_pdf_constructor_base_examples_spec'

describe ClaimsApi::V2::PoaPdfConstructor::Base do
  subject(:pdf_constructor_instance) { described_class.new }

  describe '#set_limitation_of_consent_check_box' do
    context 'marking the checkboxes correctly' do
      it_behaves_like 'shared pdf constructor base behavior'
    end
  end
end
