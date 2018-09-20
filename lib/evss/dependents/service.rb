# frozen_string_literal: true

module EVSS
  module Dependents
    class Service < EVSS::Service
      configuration EVSS::Dependents::Configuration

      def retrieve
        perform(:get, 'load/retrieve')
      end

      def clean_form(form)
        perform(:post, 'inflightform/cleanForm', form.to_json, headers)
      end

      def validate(form)
        perform(:post, 'inflightform/validateForm', form.to_json, headers)
      end

      def save(form)
        perform(:post, 'inflightform/saveForm', form.to_json, headers)
      end

      def submit(form)
        perform(:post, 'form686submission/submit', form.to_xml(root: 'submit686Request'), { 'Content-Type' => 'application/xml' })
      end
    end
  end
end
