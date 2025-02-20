# frozen_string_literal: true

require 'rails_helper'
require 'va1010_forms/utils'

RSpec.describe VA1010Forms::Utils do
  subject do
    test_class = Class.new do
      include VA1010Forms::Utils
    end
    test_class.new
  end

  describe '#soap' do
    subject do
      super().soap
    end

    it 'returns soap client' do
      expect(subject).to be_a(Savon::Client)
    end

    context 'configuration values' do
      subject { super().globals }

      let(:wsdl_path) { 'my/path/from/wsdl' }

      before do
        stub_const('HCA::Configuration::WSDL', :wsdl_path)
      end

      it 'has correct config' do
        expect(subject[:wsdl]).to eq :wsdl_path
        expect(subject[:env_namespace]).to eq :soap
        expect(subject[:element_form_default]).to eq :qualified
        expect(subject[:namespaces]).to eq({ 'xmlns:tns': 'http://va.gov/service/esr/voa/v1' })
        expect(subject[:namespace]).to eq 'http://va.gov/schema/esr/voa/v1'
      end
    end
  end
end
