require 'nokogiri'
require 'securerandom'
require 'fileutils'

class PdfToHtmlService
  def initialize(pdf_file)
    @pdf_file = pdf_file
    @random_id = SecureRandom.hex(4)
    @temp_pdf = Rails.root.join("tmp", "pdf_#{@random_id}.pdf").to_s
    @temp_html = Rails.root.join("tmp", "pdf_#{@random_id}.html").to_s
    @final_html_file = Rails.root.join("tmp", "accessible_#{@random_id}.html").to_s
  end

  def convert
    save_pdf
    run_pdf2htmlEX
    process_html
    cleanup_temp_files
    File.read(@final_html_file)
  end

  private

  def save_pdf
    File.open(@temp_pdf, "wb") { |file| file.write(@pdf_file.read) }
  end

  def run_pdf2htmlEX
    system("docker run -ti --rm -v "`pwd`":/pdf -w /pdf pdf2htmlex/pdf2htmlex:0.18.8.rc2-master-20200820-alpine-3.12.0-x86_64 --zoom 1.3 \"#{@temp_pdf}\" \"#{@temp_html}\"")
    raise "pdf2htmlEX conversion failed" unless File.exist?(@temp_html)
  end

  def process_html
    doc = Nokogiri::HTML(File.read(@temp_html))

    doc.search("div").each do |div|
      style = div["style"] || ""
      div.name = "h1" if style.include?("font-size:24px")
      div.name = "h2" if style.include?("font-size:18px")
    end

    doc.search("div").each do |div|
      if div.text.strip.start_with?("•")
        div.name = "li"
        div.content = div.text.strip.sub(/^•\s?/, "")
      end
    end

    list_items = doc.search("li")
    unless list_items.empty?
      ul = Nokogiri::XML::Node.new("ul", doc)
      list_items.each { |li| ul.add_child(li) }
      doc.at("body").add_child(ul)
    end

    doc.search("table").each do |table|
      thead = Nokogiri::XML::Node.new("thead", doc)
      tbody = Nokogiri::XML::Node.new("tbody", doc)

      rows = table.search("tr")
      if rows.any?
        header_row = rows.shift
        header_row.search("td").each do |cell|
          cell.name = "th"
          cell["scope"] = "col"
        end
        thead.add_child(header_row)
      end

      rows.each { |row| tbody.add_child(row) }
      table.add_child(thead)
      table.add_child(tbody)
    end

    doc.search("img").each { |img| img["alt"] ||= "Extracted image from PDF" }
    doc.search("*").each { |node| node.remove_attribute("style") }

    File.write(@final_html_file, doc.to_html)
  end

  def cleanup_temp_files
    FileUtils.rm_f([@temp_pdf, @temp_html])
  end
end
