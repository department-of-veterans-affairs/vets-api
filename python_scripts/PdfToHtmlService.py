#import sys
#sys.path.append("/Users/juliusahenkora/Development/VRO/vets-api/python_scripts")
from pdftranscript.transcript import batch_process

import os
import uuid
import shutil
import subprocess
from pathlib import Path
from PyPDF2 import PdfReader
from bs4 import BeautifulSoup

class PdfToHtmlService:
    def __init__(self, pdf_file, base_dir=None):
        self.pdf_file = pdf_file
        self.random_id = uuid.uuid4().hex[:8]

        #Set directory paths for pdf2html and pdftranscript
        self.base_dir = Path(base_dir or "./tmp")
        self.base_dir_html = Path(base_dir or "./tmp/HTML")
        self.base_dir_pdf = Path(base_dir or "./tmp/PDF")
        self.base_dir_htm = Path(base_dir or "./tmp/HTM")


	#Create corresponding directories
        self.base_dir.mkdir(parents=True, exist_ok=True)
        self.base_dir_pdf.mkdir(parents=True, exist_ok=True)
        self.base_dir_html.mkdir(parents=True, exist_ok=True)
        self.base_dir_htm.mkdir(parents=True, exist_ok=True)


        self.temp_pdf = self.base_dir_pdf / f"pdf_{self.random_id}.pdf"
        self.temp_html = self.base_dir_html / f"pdf_{self.random_id}.html"
        self.final_html_file = self.base_dir_htm / f"accessible_{self.random_id}.htm"
        self.semantic_html_file = self.base_dir_htm / f"pdf_{self.random_id}.htm"

    def convert(self):
        self.save_pdf()
        self.extract_pdf_metadata()
        self.run_pdf2htmlex()
        self.run_pdftranscript()
        self.process_html()

    def save_pdf(self):
        with open(self.temp_pdf, "wb") as out_file:
            out_file.write(self.pdf_file.read())

    def extract_pdf_metadata(self):
        with open(self.temp_pdf, "rb") as f:
            reader = PdfReader(f)
            metadata = reader.metadata
            info = reader.trailer.get('/Info', {})
            print(f"Metadata: {metadata}")
            print(f"Info: {info}")
            return {"metadata": metadata, "info": info}

    def run_pdf2htmlex(self):
        command = [
            "docker", "run", "--rm",
            "-v", f"{self.base_dir_pdf.absolute()}:/pdf",
            "-v", f"{self.base_dir_html.absolute()}:/HTML",
            "-w", "/pdf",
            "pdf2htmlex/pdf2htmlex:0.18.8.rc2-master-20200820-alpine-3.12.0-x86_64",
	    "--embed-external-font","0",
            "--process-nontext"," 0",
            "--embed","cfijo",
            "--dest-dir", f"/HTML",
            f"/pdf/{self.temp_pdf.name}"
        ]

        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        print(f"STDOUT:\n{result.stdout}")
        print(f"STDERR:\n{result.stderr}")

        # Expecting the HTML to be named similar to the PDF (per pdf2htmlEX default behavior)
        expected_html = self.base_dir_html / (self.temp_pdf.stem + ".html")
        if not result.returncode == 0 or not expected_html.exists():
            raise RuntimeError(f"pdf2htmlEX conversion failed: {result.stderr}")

        self.temp_html = expected_html

    def process_html(self):
        with open(self.semantic_html_file, "r", encoding="utf-8") as f:
            soup = BeautifulSoup(f, "html.parser")

        html_tag = soup.find("html")
        if html_tag and not html_tag.has_attr("lang"):
            html_tag["lang"] = "en"

        if not soup.title:
            head = soup.head or soup.new_tag("head")
            soup.html.insert(0, head)
            title_tag = soup.new_tag("title")
            title_tag.string = "VA Decision Letter"
            head.append(title_tag)

        if not soup.find("main"):
            body = soup.body
            main_tag = soup.new_tag("main", role="main", tabindex="0")
            children = list(body.contents)
            for child in children:
                main_tag.append(child.extract())
            body.append(main_tag)

        for heading in soup.find_all(["h1", "h2", "h3", "h4", "h5", "h6"]):
            if not heading.get_text(strip=True):
                print(f"⚠️ Empty heading found: {heading}")
                heading.string = "Section Title"

        prev_level = 0
        for heading in soup.find_all(["h1", "h2", "h3", "h4", "h5", "h6"]):
            current_level = int(heading.name[1])
            if prev_level and current_level > prev_level + 1:
                print(f"⚠️ Skipped heading from h{prev_level} to h{current_level}: {heading.text}")
            prev_level = current_level

        with open(self.final_html_file, "w", encoding="utf-8") as out_file:
            out_file.write(str(soup.prettify()))

        print(f"✅ Intermediate accessible HTML written to {self.final_html_file}")

    def run_pdftranscript(self):

        print(f"📘 Running PDFtranscript batch on directory: {self.base_dir / 'HTML'}")

        try:
            batch_process(str(self.base_dir_html /  "*.html"), limit=None)
            print(f"✅ Semantic HTML batch completed. Output saved in: {self.semantic_html_file}")
        except Exception as e:
            raise RuntimeError(f"PDFtranscript batch_process failed: {e}")

        print(f"✅ Semantic HTML written to {self.base_dir_html}")

with open("./tmp/fake-decision-letter-0a8fd999-999b-45f0-968b-af8d67af85ae.pdf", "rb") as f:
    service = PdfToHtmlService(f)
    service.convert()
