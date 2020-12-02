require "prawn"
pdf = Prawn::Document.new
table = [
	    [ 'ID', 'Site Name', 'Site Description', 'Post Title', 'Author'],
	        [ 1, 'Ruby in Rails', 'Ruby on Rails development tutorials for beginner and advanced learners.', 'Rails generate password protected PDF file', 'Akshay Mohite' ],
]

#pdf.table table
p pdf.methods.sort
pdf.text("I am locked!")
pdf.encrypt_document(
	    user_password: "cris",
	        owner_password: "cris",
		    permissions: {
			        print_document: true,
				        modify_contents: false,
					        copy_contents: false,
						        modify_annotations: false
		    }
)
pdf.render_file "locked.pdf"
