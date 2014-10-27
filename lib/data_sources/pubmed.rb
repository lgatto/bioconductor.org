# encoding: utf-8

require 'rubygems'
require 'httparty' # OpenSSL
require 'time' # Date.time
require 'yaml'
require 'fileutils'
require 'nokogiri' # Nokogiri::HTML
require 'open-uri' # open
require 'nanoc3'
require 'nanoc'

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
	
	## search query
        search = "#{baseurl}esearch.fcgi?db=#{db}&term=bioconductor&retmax=#{retmax}&usehistory=y"
        doc = nil
        begin
            doc = Nokogiri::XML(open(search))
        rescue
            return []
        end
	#webenv = doc.xpath("//eSearchResult/WebEnv").text
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
    
    def fetchOld
        baseurl = "http://www.ncbi.nlm.nih.gov/pubmed"
	dispmax = 3
        query = "#{baseurl}?term=bioconductor&dispmax=#{dispmax}"
	
	
        # TODO ensure url exists?
        # why is the certificate not valid from dan's home laptop?
        doc = nil
        begin
            doc = Nokogiri::HTML(open(query))
        rescue
            return []
        end
        results = doc.css(".rslt")
        return [] if results.empty?
        
	results.each do |result|
	    a = result.css(".title a")
	    href = a.attr('href').value
	    title = a.text
	    author = result.css(".desc").text
	    journal = result.css(".jrnl").text
	    details = result.css(".details").text
	    details = details[journal.length+2..details.length-1]
	      
            next unless i % 2 == 0
            x = a[i]
            href = x.attr('href')
            subject = x.text.strip.sub(/^\[Bioc-devel\] /, "")
            msg_url = url.sub("date.html", href)
            msg_doc = nil
            begin
                msg_doc = Nokogiri::HTML(open(msg_url, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}))
            rescue
                return []
            end
            datestamp = msg_doc.css("i").first.text#.gsub(/[ ]{2,}/," ")
            datestamp.sub!("CEST", "+0200")
            datestamp.sub!("CET", "+0100")
            dt = Time.strptime(datestamp, "%a %b %e %H:%M:%S %z %Y")
            isodate = dt
            #isodate = Time.parse(datestamp)#.utc#.iso8601
            attributes = {
                :title => subject,
                :date => isodate,
                :link => msg_url,
                :author => "unused"
            }
            content = "unused"
            identifier = "/#{href.gsub(/\.html/, "")}/"
            mtime = nil
            ret.push Nanoc3::Item.new(content, attributes, identifier, mtime)
        end
        ret.reverse
    end


    def items
        fetch()
    end

end
