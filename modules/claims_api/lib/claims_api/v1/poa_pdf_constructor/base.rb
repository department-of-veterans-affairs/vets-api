# frozen_string_literal: true

require 'pdf_fill/filler'

module ClaimsApi
  module V1
    module PoaPdfConstructor
      class Base
        def initialize
          @page1_path = nil
          @page2_path = nil
          @page3_path = nil
          @page4_path = nil
        end

        def construct(data, id: SecureRandom.uuid)
          sign_pdf(data['signatures'])
          fill_pdf(data)
          combine_pdf(id, @page1_path, @page2_path, @page3_path, @page4_path)
        end

        protected

        # @return [String] Path to page 1 pdf template file
        def page1_template_path
          raise 'NotImplemented' # Extend this class and implement
        end

        # @return [String] Path to page 2 pdf template file
        def page2_template_path
          raise 'NotImplemented' # Extend this class and implement
        end

        # @return [String] Path to page 3 pdf template file
        def page3_template_path
          raise 'NotImplemented' # Extend this class and implement
        end

        # @return [String] Path to page 4 pdf template file
        def page4_template_path
          raise 'NotImplemented' # Extend this class and implement
        end

        # @param signatures [Hash] Should contain both Veteran and representative signatures
        #
        # @return [Array(ClaimsApi::V1::PoaPdfConstructor::Signature)] List of signatures to attach to first page of pdf
        def page1_signatures(_signatures)
          raise 'NotImplemented' # Extend this class and implement
        end

        # @return [Array(ClaimsApi::V1::PoaPdfConstructor::Signature)] Signatures to attach to second page of pdf
        def page2_signatures(_signatures)
          raise 'NotImplemented' # Extend this class and implement
        end

        # @param data [Hash] Data to fill in pdf form
        #
        # @return [Hash] Data to fill in first page of pdf form
        def page1_options(_data)
          raise 'NotImplemented' # Extend this class and implement
        end

        # @param data [Hash] Data to fill in pdf form
        #
        # @return [Hash] Data to fill in second page of pdf form
        def page2_options(_data)
          raise 'NotImplemented' # Extend this class and implement
        end

        # @param data [Hash] Data to fill in pdf form
        #
        # @return [Hash] Data to fill in second page of pdf form
        def page3_options(_data)
          raise 'NotImplemented' # Extend this class and implement
        end

        # @param data [Hash] Data to fill in pdf form
        #
        # @return [Hash] Data to fill in second page of pdf form
        def page4_options(_data)
          raise 'NotImplemented' # Extend this class and implement
        end

        #
        # Converts segmented address information into single string representation.
        #
        # @param address [Hash] Segmented data representing an address
        #
        # @return [String] Single string representation of provided address
        def stringify_address(address)
          return if address.nil?

          "#{address['numberAndStreet']}, #{address['city']} #{address['state']} #{address['zipFirstFive']}"
        end

        def handle_country_code(phone)
          return if phone.blank?

          country_code = phone['countryCode']
          area_code = phone['areaCode']
          phone_number = phone['phoneNumber']

          if country_code.blank?
            "#{area_code} #{phone_number}"
          else
            "+#{country_code} #{area_code} #{phone_number}"
          end
        end

        private

        #
        # Produce final pdf with all pages combined.
        #
        # @param id [type] [description]
        # @param page1_path [String] Path to page 1 of pdf
        # @param page2_path [String] Path to page 2 of pdf
        #
        # @return [String] Path to final pdf
        def combine_pdf(id, page1_path, page2_path, page3_path, page4_path)
          output_path = "/tmp/#{id}_final.pdf"

          pdf = CombinePDF.new
          pdf << CombinePDF.load(page1_path)
          pdf << CombinePDF.load(page2_path)
          pdf << CombinePDF.load(page3_path) unless page3_path.nil?
          pdf << CombinePDF.load(page4_path) unless page4_path.nil?
          pdf.save(output_path)

          output_path
        end

        #
        # Fill in pdf form fields based on data provided.
        #
        # @param data [Hash] Data to fill in pdf form with
        def fill_pdf(data)
          pdftk = PdfForms.new(Settings.binaries.pdftk)

          temp_path = Rails.root.join('tmp', "poa_#{Time.now.to_i}_page_1.pdf")
          pdftk.fill_form(
            @page1_path,
            temp_path,
            page1_options(data),
            flatten: true
          )
          @page1_path = temp_path

          temp_path = Rails.root.join('tmp', "poa_#{Time.now.to_i}_page_2.pdf")
          pdftk.fill_form(
            @page2_path,
            temp_path,
            page2_options(data),
            flatten: true
          )
          @page2_path = temp_path
        end

        # positive grants are provided in the form data, but the pdf form reverses this logic in box 20
        # e.g. if form data includes ['ABC'], then ABC in box 20 will NOT be checked, but everything else will
        def set_limitation_of_consent_check_box(consent_limits, item)
          return 0 if consent_limits.blank?

          consent_limits.include?(item) ? 0 : 1
        end

        #
        # Add provided signatures to pdf pages.
        #
        # @param signatures [Hash] Hash of both signatures provided
        def sign_pdf(signatures)
          @page1_path = insert_signatures(page1_template_path, page1_signatures(signatures))
          @page2_path = insert_signatures(page2_template_path, page2_signatures(signatures))
          @page3_path = page3_template_path
          @page4_path = page4_template_path
        end

        #
        # Attach signature images to single page of pdf.
        #
        # @param page_template [String] Path to single page template of pdf
        # @param signatures [Array(ClaimsApi::V1::PoaPdfConstructor::Signature)] List of signatures to attach
        #
        # @return [type] [description]
        def insert_signatures(page_template, signatures)
          stamp_path = "#{::Common::FileHelpers.random_file_path}.pdf"

          Prawn::Document.generate(stamp_path, margin: [0, 0]) do |pdf|
            signatures.each do |signature|
              pdf.image signature.path, at: [signature.x, signature.y], height: signature.height
            end
          end

          stamp(page_template, stamp_path, delete_source: false)
        rescue Prawn::Errors::UnsupportedImageType
          raise ClaimsApi::StampSignatureError.new(
            message: 'One or more signatures could not be inserted',
            detail: 'One or more signatures did not have a recognized image format'
          )
        end

        def stamp(file_path, stamp_path, delete_source: true)
          output_path = "#{::Common::FileHelpers.random_file_path}.pdf"

          PdfFill::Filler::PDF_FORMS.stamp(file_path, stamp_path, output_path)
          File.delete(file_path) if delete_source

          output_path
        rescue
          ::Common::FileHelpers.delete_file_if_exists(output_path)
          raise
        end
      end
    end
  end
end
