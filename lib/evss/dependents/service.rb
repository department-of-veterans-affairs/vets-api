# frozen_string_literal: true

module EVSS
  module Dependents
    class Service < EVSS::Service
      configuration EVSS::Dependents::Configuration

      def retrieve
        perform(:get, 'load/retrieve')
      end

      def clean_form(form)
        perform(:post, 'inflightform/cleanForm', form.to_json, headers).body
      end

      def validate(form)
        perform(:post, 'inflightform/validateForm', form.to_json, headers).body
      end

      def save(form)
        perform(:post, 'inflightform/saveForm', form.to_json, headers).body
      end

      def submit(form, form_id)
        form['submitProcess']['application']['draftFormId'] = form_id
        change_evss_times!(form)
        res = perform(
          :post,
          'form686submission/submit',
          form.to_xml(root: 'submit686Request'),
          'Content-Type' => 'application/xml'
        )
        Hash.from_xml(res.body)
      end

      private

      def change_evss_times!(object)
        if object.is_a?(Hash)
          object.each do |k, v|
            if k.downcase.include?('date') && v.is_a?(Numeric)
              object[k] = convert_evss_time(v)
            else
              change_evss_times!(v)
            end
          end
        elsif object.is_a?(Array)
          object.each do |item|
            change_evss_times!(item)
          end
        end
      end

      def convert_evss_time(time)
        Time.strptime(time.to_s, '%Q').utc.iso8601
      end
    end
  end
end
