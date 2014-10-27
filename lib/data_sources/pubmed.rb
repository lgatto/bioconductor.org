# encoding: utf-8
require 'nokogiri'
require 'open-uri'
require 'nanoc3'

class PubmedPapers < Nanoc3::DataSource
    identifier :pubmed_papers
    
    ## join the content of NodeSet elements
    def join(x, sep = ",")
      y = []
      x.each do |element|
	y.push element.text
      end
      y.join(sep)
    end

    ## function used to extract XML content
    def extract(item, name, join = FALSE, sep = ", ")
      join(item.xpath(".//Item[@Name='#{name}']"), sep = sep)
    end
    
    def fetch
        baseurl = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/"
	db = "pubmed"
	retmax = 20
	
	## search
        search = "#{baseurl}esearch.fcgi?db=#{db}&term=bioconductor&retmax=#{retmax}"
        doc = nil
        begin
            doc = Nokogiri::XML(open(search))
        rescue
            return []
        end
        idl = doc.xpath("/eSearchResult/IdList/Id")
	return [] if idl.empty?
	
	## query for results 
	query = "#{baseurl}esummary.fcgi?db=#{db}&id=#{join(idl)}"
	doc = nil
        begin
            doc = Nokogiri::XML(open(query))
        rescue
            return []
        end
	
	items = doc.xpath("/eSummaryResult/DocSum")
	return [] if items.empty?
	
	## define XML attribute name mapping
	mapping = {
	  :date => "PubDate",
	  :title => "Title",
	  :author => "Author",
	  :journal => "Source",
	  :volume => "Volume",
	  :issue => "Issue",
	  :pages => "Pages",
	  :doi => "DOI"
	}
	
	## iterate over results
	ret = []
	items.each do |item|
	  id = "/#{item.xpath("./Id").text}/"
	  attributes = {}
	  mapping.each { |key, val| attributes[key] = extract(item, val) }
	  attributes[:year] = attributes[:date][0..3]
	  ret.push Nanoc3::Item.new("unused", attributes, id, nil)               
	end
	
	ret
    end
    
    def items
        fetch()
    end

end
