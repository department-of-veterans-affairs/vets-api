# frozen_string_literal: true

require 'pdf_fill/filler'

module RepresentationManagement
  module V0
    module PdfConstructor
      class Base
        def initialize(tempfile)
          @tempfile = tempfile
          @template_path = nil
        end

        def construct(data)
          set_template_path
          fill_and_combine_pdf(data)
        end

        protected

        # @return [String] Path to page 1 pdf template file
        def template_path
          raise 'NotImplemented' # Extend this class and implement
        end

        # @param data [Hash] Data to fill in pdf form
        #
        # @return [Hash] Data to fill in first page of pdf form
        def template_options(_data)
          raise 'NotImplemented' # Extend this class and implement
        end

        #
        # Set the template path that is defined by the subclass
        #
        # @param data [Hash] Hash of data to add to the pdf
        def set_template_path
          @template_path = template_path
        end

        #
        # Determine if the next steps page should be included in the pdf
        #
        # @return [Boolean] True if the next steps page should be included
        def next_steps_page?
          raise 'NotImplemented' # Extend this class and implement
        end

        #
        # Add the contact information to the next steps page
        #
        # @param pdf [Prawn::Document] The pdf to add the contact information to
        def next_steps_contact(_pdf, _data)
          raise 'NotImplemented' # Extend this class and implement
        end

        # rubocop:disable Layout/LineLength
        def next_steps_above_contact(pdf)
          pdf.font_size(20)
          pdf.text('Fill out your form to appoint a VA accredited representative or VSO')
          pdf.move_down(10)
          pdf.font_size(12)
          pdf.text('VA Form 21-22a')
          pdf.move_down(10)
          pdf.font_size(16)
          pdf.text('Your Next Steps')
          pdf.move_down(10)
          pdf.font_size(12)
          pdf.text('Both you and the accredited representative will need to sign your form.  You can bring your form to them in person or mail it to them.')
          pdf.move_down(30)
        end

        def next_steps_below_contact(pdf)
          pdf.move_down(30)
          pdf.text('After your form is signed, you or the accredited representative can submit it online, by mail, or in person.')
          pdf.move_down(10)
          pdf.font_size(16)
          pdf.text('After you submit your printed form')
          pdf.move_down(10)
          pdf.font_size(12)
          pdf.text("We'll confirm that the accredited representative is available to help you.  Then we'lle update your VA.gov profile with their information.")
          pdf.move_down(10)
          pdf.text('We usually process your form within 1 week.  You can contact the accredited representative any time to aks when they can start helping you.')
          pdf.move_down(10)
          pdf.font_size(14)
          pdf.text('Need help?')
          pdf.move_down(10)
          pdf.font_size(12)
          pdf.text("You can call us at 800-698-2411, ext. 0 (TTY: 711).  We're here 24/7.")
        end
        # rubocop:enable Layout/LineLength

        private

        #
        # Fill in pdf form fields based on data provided, then combine all
        # the pages into a final pdf.  We create an inner tempfile to fill
        # and the output from this method is written to a tempfile in
        # the controller.  Start with a Next Steps page if needed.
        #
        # @param data [Hash] Data to fill in pdf form with
        # rubocop:disable Metrics/MethodLength
        def fill_and_combine_pdf(data)
          pdftk = PdfForms.new(Settings.binaries.pdftk)

          if next_steps_page?
            next_steps_tempfile = Tempfile.new
            next_steps = Prawn::Document.new
            next_steps_above_contact(next_steps)
            next_steps_contact(next_steps, data)
            next_steps_below_contact(next_steps)
            next_steps.render_file(next_steps_tempfile.path)
          end

          # We need a Tempfile here because CombinePDF needs a file to load.
          template_tempfile = Tempfile.new
          # Fill that template with the form data
          pdftk.fill_form(
            @template_path,
            template_tempfile.path,
            template_options(data),
            flatten: true
          )
          @template_path = template_tempfile.path
          template_tempfile.rewind

          output_path = @tempfile.path

          pdf = CombinePDF.new
          pdf << CombinePDF.load(next_steps_tempfile.path) if next_steps_page?
          pdf << CombinePDF.load(@template_path)
          pdf.save(output_path)

          @tempfile.rewind
          # Delete the tempfile we created now that CombinePDF has saved
          # the final pdf.
          template_tempfile.unlink
          next_steps_tempfile.unlink if next_steps_page?
        end
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
