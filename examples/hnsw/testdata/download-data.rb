require 'net/http'
require 'uri'

# URL of the book on the Gutenberg Project: Alice's Adventures in Wonderland
book_url = 'https://www.gutenberg.org/cache/epub/11/pg11.txt'

# Download the book content
uri = URI.parse(book_url)
response = Net::HTTP.get_response(uri)
book_content = response.body

# Split the book into sections
sections = book_content.split(/\n\n+/)

# Write each section to a sequentially-numbered file
section_number = 1
sections.each do |section|
  filename = "section_#{section_number.to_s.rjust(3, '0')}.txt"
  File.write(filename, section)
  section_number += 1
end
