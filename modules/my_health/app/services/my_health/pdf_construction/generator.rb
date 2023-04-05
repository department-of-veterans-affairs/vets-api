# frozen_string_literal: true

module MyHealth
  module PdfConstruction
    class Generator
      def initialize(filename, vaccines_list)
        @filename = filename
        @vaccines_list = vaccines_list
      end

      def make_top(pdf, data)
        pdf.bounding_box([pdf.bounds.left, pdf.bounds.top + 110], width: pdf.bounds.width) do
          pdf.table(data, cell_style: { size: 11, borders: [], padding: 0 })
        end
      end

      def make_title(pdf)
        pdf.bounding_box([pdf.bounds.left, pdf.bounds.top + 85], width: pdf.bounds.width, height: 40) do
          pdf.stroke_bounds
          pdf.move_down 9
          pdf.font 'Bitter'
          pdf.text 'Vaccines', align: :center, style: :bold, size: 20
        end
      end

      def make_subtitle(pdf)
        pdf.move_down 10
        pdf.font 'OpenSans'
        pdf.text 'Your VA vaccines list may not be complete. ' \
                 'If you have any questions about your information, ' \
                 'visit the FAQs or contact your VA Health Care team.',
                 size: 11
      end

      def make_cell(pdf, options)
        Prawn::Table::Cell::Text.new(pdf, [0, 0], options)
      end

      def make_header(pdf, page)
        header_data = []
        third = pdf.bounds.width / 3
        header_data.push make_cell(pdf, content: 'Doe, John R., Jr. - DOB 12/12/1980', width: third)
        header_data.push make_cell(pdf, content: '<b>CONFIDENTIAL</b>', inline_format: true, align: :center,
                                        width: third)
        header_data.push make_cell(pdf, content: "Page #{page} of #{pdf.page_count}", align: :right, width: third)

        make_top(pdf, [header_data])
        make_title(pdf)
        make_subtitle(pdf)
      end

      def make_footer(pdf)
        pdf.text_box "Report generated on #{Time.now.getlocal.strftime('%B %d, %Y')}", at: [0, -10], height: 50
      end

      def every_page_content(pdf)
        pdf.page_count.times do |i|
          page_num = i + 1
          pdf.go_to_page page_num
          make_header(pdf, page_num)
          make_footer(pdf)
        end
      end

      def make_labeled_data_point(pdf, name, data_point)
        [make_cell(pdf, content: "<b>#{name}:</b> #{data_point}", inline_format: true, padding: [5, 20])]
      end

      def make_label(pdf, name)
        [make_cell(pdf, content: "<b>#{name}:</b>", inline_format: true, padding: [5, 20])]
      end

      def make_data_point(pdf, data_point)
        [make_cell(pdf, content: data_point, padding: [0, 0, 14.2, 20])]
      end

      def make_vaccine(pdf, vaccine)
        vaccine.push [make_cell(pdf, content: "<font name='Bitter' size='20'><b>Flu (influenza)</b></font>",
                                     inline_format: true, leading: 10)]
        vaccine.push make_labeled_data_point(pdf, 'Date received', 'March 25, 2022')
        vaccine.push make_labeled_data_point(pdf, 'Type and dosage', 'Flu (influenza)')
        vaccine.push make_labeled_data_point(pdf, 'Series', 'no series reported at this time')
        vaccine.push make_labeled_data_point(pdf, 'Location', 'Dayton VA Medical Center')
        vaccine.push make_labeled_data_point(pdf, 'Reactions recorded by provider', 'none reported')
        vaccine.push make_label(pdf, 'Provider comments')
        vaccine.push make_data_point(pdf, 'No information or feedback given')
        vaccine
      end

      def make_vaccines_pdf
        Prawn::Document.generate(@filename, margin: [125, 35, 35, 35]) do |pdf|
          pdf.font_families.update('OpenSans' => {
                                     normal: 'public/fonts/sourcesanspro-regular-webfont.ttf',
                                     bold: 'public/fonts/sourcesanspro-bold-webfont.ttf'
                                   },
                                   'Bitter' => {
                                     normal: 'public/fonts/bitter-regular.ttf',
                                     bold: 'public/fonts/bitter-bold.ttf'
                                   })
          vaccines = []

          @vaccines_list.length.times do
            vaccines_table = pdf.make_table(make_vaccine(pdf, []), cell_style: { borders: [] })
            vaccines.push [vaccines_table]
          end

          pdf.table(vaccines, width: pdf.bounds.width, cell_style: { inline_format: true, borders: [] }) do |t|
            t.cells.padding = [10, 0]
          end

          pdf.font 'OpenSans'
          every_page_content(pdf)
        end
      end
    end
  end
end
