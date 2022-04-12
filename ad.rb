# coding: utf-8
require 'cgi'
require 'digest'
require 'fileutils'
require 'json'
require 'net/http'
require 'nokogiri'
require 'open-uri'

if ARGV.length == 0 then
  puts "$0 <url>"
  exit 1
end

FileUtils.mkdir_p 'cache'
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

class AD02
  def process url
    digest = Digest::MD5.hexdigest(url)
    filename = "cache/#{digest}.html"
    unless File.exists?(filename)
      open(filename, 'w') do |f|
        f.write URI.open(url).read
      end
    end
    document = Nokogiri::HTML(open(filename).read)
    script = document.xpath('//script[contains(text(), "manifestUrl")]').first.content
    #puts script.inspect
    manifestUrl = /"manifestUrl": "(.*)"/.match(script)[1].gsub("\\", "")
    #puts manifestUrl.inspect
    manifest = JSON::parse(URI.open(manifestUrl).read)
    #puts manifest.inspect
    manifest['sequences'].each do |sequence|
      sequence['canvases'].each do |canvas|
        #puts "## CANVAS #{canvas['@id']} (#{url})"
        next if canvas['@id'] != url.gsub(/daogrp/, 'canvas')
        canvas['rendering'].each do |rendering|
          if rendering['label'] =~ /charger le document original/ then
            #puts "HERE "
            #puts "  #{rendering['@id'].inspect}"
            uri = URI.parse(rendering['@id'])
            #puts uri.inspect
            query = CGI.parse(uri.query)
            #puts query.inspect
            quri = URI.parse(query['file'][0])
            path = quri.path
            basename = File.basename(path)
            unless File.exists?(basename)
              open(basename, 'w') do |f|
                f.write URI.open(rendering['@id']).read
              end
            end
            return basename
          end
        end
      end
    end
  end
end

class AD14
  def process url
    uri = URI.parse(url)
    puts "[INFO] ad14 #{uri.inspect}"
    basename = File.basename(uri.path)
    unless File.exists? "ad14-#{basename}.jpg"
      open("ad14-#{basename}.jpg", 'w') do |f|
        f.write URI.open("https://archives.calvados.fr/images/#{basename}.jpg").read
      end
    else
      puts "[WARNING] #{basename} already exists"
    end
    return "ad14-#{basename}.jpg"
  end
end

class AD21
  def process url
    digest = Digest::MD5.hexdigest(url)
    filename = "cache/#{digest}.html"
    unless File.exists?(filename)
      open(filename, 'w') do |f|
        f.write URI.open(url).read
      end
    end
    document = Nokogiri::HTML(open(filename).read)
    image = document.xpath('//div[@class="div_image_single"]/img').first
    #puts image.inspect
    
    scripts = document.xpath('//script[not(@*) and contains(text(), "inputvue_actuelle")]/text()').first.content
    val = /\.val\(([0-9]+)\)/.match(scripts)[1].to_i
    #puts val.inspect
    
    tabs = document.xpath('//script[not(@*) and contains(text(), "tab_images_deja_en_cache")]/text()').first.content
    eval("tabs = #{/\[(.*)\]/.match(tabs)[1]}")
    #puts tabs.inspect
    
    data_original = document.xpath("//img[@id='visu_image_#{val}']/@data-original").first.content
    #puts data_original.inspect
    
    w = 3000
    h = 2000
    tabs.each do |tab|
      b = File.basename(data_original, '.*')
      if tab[0] =~ /#{b}/ then
        w = tab[3].to_i
        h = tab[4].to_i
        #puts "found #{tab}"
      end
    end
    
    uri = URI.parse("https://archives.cotedor.fr//v2/ad21/visualiseur/impression.pdf")
    res = Net::HTTP.post_form(uri, {
                                imprime_id: 0,
                                imprime_img: data_original,
                                imprime_contraste: 1,
                                imprime_luminosite: 1,
                                imprime_negatif: false,
                                imprime_angle: 0,
                                imprime_num_page: val,
                                imprime_total: 220,
                                imprime_x: 0,
                                imprime_y: 0,
                                imprime_w: w,
                                imprime_h: h,
                                imprime_vue_actuelle: 1
                              })
    filename = "cache/#{digest}.pdf"
    unless File.exists?(filename)
      open(filename, 'w') do |f|
        f.write res.body
      end
    end

    basename = "#{File.basename(data_original, '.*')}.jpg"
    unless File.exists? basename
    %x{pdfimages -j cache/#{digest}.pdf #{File.basename(data_original, ".*")}}
    FileUtils.rm Dir.glob("#{File.basename(data_original, '.*')}-*.ppm")
    FileUtils.mv "#{File.basename(data_original, '.*')}-002.jpg", "#{File.basename(data_original, '.*')}.jpg"
    end
    return "#{File.basename(data_original, '.*')}.jpg"
  end
end

class AD59
  def process url
    uri = URI.parse(url)
    basename = File.basename(uri.path)
    unless File.exists? basename
    open("ad59-#{basename}.jpg", 'w') do |f|
      f.write URI.open("https://archives.calvados.fr/images/#{basename}.jpg").read
    end
    end
    return basename
  end
end

class AD78
  def process uri_str, limit=10
    raise ArgumentError, 'too many redirects' if limit == 0
    uri = URI(uri_str)
    response = Net::HTTP.get_response(uri)
    case response
    when Net::HTTPSuccess then
      puts response.inspect
    when Net::HTTPRedirection
      puts " REDIRECTION to s:#{uri.scheme} h:#{uri.host} l:#{response['location']}"
      puts " DIFFERENCE w/  https://archives.yvelines.fr/rechercher/archives-en-ligne/registres-paroissiaux-et-detat-civil/registres-paroissiaux-et-detat-civil?detail=956990&arko_default_618914e3ee7e4--modeRestit=arko_default_6189505357e83#visionneuse-manual|/_recherche-api/visionneuse-infos/arko_default_618914e3ee7e4/arko_fiche_619516aba7f0e/arko_default_61894d9727a8e/image/1459649/97|0|97"
      #new_url = URI.parse(URI.parse(response['location'].strip))
      parts = response['location'].split('?')
      
      path = parts[0]
      query = {}
      parts[1].split('&').each do |q|
        q2 = q.split('=')
        query[q2[0]] = q2[1]
      end
      
      redirect = URI::HTTP.build(host: uri.host, path: path, query: URI.encode_www_form(query))
      puts "REDIRECT : h:#{uri.host} p:#{path} #{redirect.inspect}"
      process redirect, limit - 1
    else
      puts reponse.value.inspect
    end
    
    return 1
    
    digest = Digest::MD5.hexdigest(url)
    filename = "cache/#{digest}.html"
    unless File.exists?(filename)
      open(filename, 'w') do |f|
        f.write URI.open(url).read
      end
    end
  end
end

class AD80
  def process url
    uri = URI.parse(url)
    basename = File.basename(uri.path)
    unless File.exists? basename
    open("ad80-#{basename}.jpg", 'w') do |f|
      f.write URI.open("https://archives.somme.fr/images/#{basename}.jpg").read
    end
    end
    return basename
  end
end

class AD95
  def process url
    digest = Digest::MD5.hexdigest(url)
    filename = "cache/#{digest}.html"
    unless File.exists?(filename)
      open(filename, 'w') do |f|
        f.write URI.open(url).read
      end
    end
    document = Nokogiri::HTML(open(filename).read)
    script = document.xpath('//script[contains(text(), "manifestUrl")]').first.content
    #puts script.inspect
    manifestUrl = /"manifestUrl": "(.*)"/.match(script)[1].gsub("\\", "")
    #puts manifestUrl.inspect
    manifest = JSON::parse(URI.open(manifestUrl).read)
    #puts manifest.inspect
    manifest['sequences'].each do |sequence|
      sequence['canvases'].each do |canvas|
        puts "## CANVAS #{canvas['@id']} (#{url})"
        next if canvas['@id'] != url.gsub(/daogrp/, 'canvas')
        canvas['rendering'].each do |rendering|
          if rendering['label'] =~ /charger le document original/ then
            puts "HERE "
            puts "  #{rendering['@id'].inspect}"
            uri = URI.parse(rendering['@id'])
            puts uri.inspect
            query = CGI.parse(uri.query)
            puts query.inspect
            quri = URI.parse(query['file'][0])
            path = quri.path
            basename = File.basename(path)
            unless File.exists? basename
            open(basename, 'w') do |f|
              f.write URI.open(rendering['@id']).read
            end
            end
            return basename
          end
        end
      end
    end
  end
end

def process_general url
  uri = URI(url)
  puts "[INFO] based on #{uri.host}"
  case uri.host
  when 'archives.aisne.fr'
    return AD02.new.process url
  when 'archives.calvados.fr'
    return AD14.new.process url
  when 'archives.cotedor.fr'
    return AD21.new.process url
  when 'archives.somme.fr'
    return AD80.new.process url
  when 'archives.valdoise.fr'
    return AD95.new.process url
  else
    raise "#{uri.host} not handled"
  end
end

if ARGV[0] =~ /\.gramps$/ then
  g = Nokogiri::XML(open(ARGV[0]).read)
  objects = g.xpath('//xmlns:objects')
  g.xpath('//xmlns:citations/xmlns:citation').each do |citation|
    objref = citation.xpath('xmlns:objref')
    # TODO il faudrait vérifier que le média porte la même description
    # que la citation
    next if objref.length > 0

    #puts citation
    
    ark = citation.xpath('xmlns:srcattribute[@type="Ark"]/@value').first
    vue = citation.xpath('xmlns:srcattribute[@type="Vue"]/@value').first
    page = citation.xpath('xmlns:page').first
    next if ark.nil?
    #puts ark.inspect
    puts "[INFO] adding objref to '#{page.content}'" unless page.nil?
    begin
      filename = process_general ark.content
    # création object
      obj = Nokogiri::XML::Node.new('object', g)
      obj['handle'] = "_#{Digest::MD5.hexdigest(rand().to_s)}"
      obj['change'] = Time.new.to_i.to_s
      obj['id'] = citation.xpath('@id').first.content.gsub('C', 'M')
      file = Nokogiri::XML::Node.new('file', g)
      file['src'] = filename
      file['mime'] = 'image/jpeg'
      file['description'] = "#{page.content}" if vue.nil?
      file['description'] = "#{page.content} - Vue #{vue.content.to_i}" unless vue.nil?
      obj.add_child file
    # ajout object dans objects
      objects.first.add_child obj
    # création objref
      objref = Nokogiri::XML::Node.new('objref', g)
      objref['hlink'] = obj['handle']
      region = Nokogiri::XML::Node.new('region', g)
      region['corner1_x'] = 0
      region['corner1_y'] = 0
      region['corner2_x'] = 100
      region['corner2_y'] = 100
      objref.add_child region
    # ajout objref dans citation
      citation.add_child objref
    rescue => e
      puts "[EXCEPTION] #{e.inspect}"
    end
    
  end
  basename = File.basename(ARGV[0], '*.gramps')
  puts "[INFO] writing #{basename}-test.gramps"
  open("#{basename}-test.gramps", 'w') do |f|
    f.write g.to_xml
  end
else
  ARGV.each do |url|
    puts "processing #{url}"
    puts process_general(url)
  end
end
