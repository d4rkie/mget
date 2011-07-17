#!/usr/bin/ruby
#
#this script is made to download manga off mangastream.net website
#if no argument is supplied it prints the list of all available chapters with their links
#to download individual chapters use "get {chapter_url}"
#
#!tip you can use any page in the chapter to get the full thing

require 'net/http'
require 'open-uri'
require 'rubygems'
require 'nokogiri'
require 'css_parser'
require 'RMagick'
require 'fileutils'

def load_mangastream_list()
    
    loaded_data = ""
    mangastream_list_url = "http://mangastream.com/manga"
    mangastream_root_url = "http://mangastream.com"
    mangas = []
    
    loaded_data = URI.parse(mangastream_list_url).read
    
#    puts(loaded_data)
    
    doc = Nokogiri::HTML.parse(loaded_data)
    
    manga_title = {:name=>'', :chapters=>[]}
    
    doc.xpath('//td').each do |parent|
      parent.children.each do |node|
        if (node.name == "strong")
          mangas.push(manga_title)
          manga_title = {:name=>'', :chapters=>[]}
          manga_title[:name] = node.text
          
          #debug
          puts "\n#{manga_title[:name]}\n\n"
        end
        if (node.name == "a")
          chapter = {:url=>'', :name=>'', :date=>''}
          chapter[:url] = node['href']
          chapter[:name] = node.text
          manga_title[:chapters].push(chapter)
          # debug
          puts "#{chapter[:name]} at #{mangastream_root_url + chapter[:url]}"
        end
      end
    end
    
    return mangas
end

def load_mangastream_chapter(url, dir)
  loaded_data = ""
  pageLinks = {}
  mangastream_root_url = "http://mangastream.com"
  current_page = ""
  css_source = ""
  page_width = 0
  page_parts = []
  page_surface = 0;

  loaded_data = URI.parse(url).read
  
  doc = Nokogiri::HTML.parse(loaded_data)
  
  tokens = url.split('/')
  
  doc.xpath("//div/a").each do |node|
    if (node['href'].include? tokens[tokens.length - 2])
      if (node.text.to_i > 0)
        pageLinks[node['href']] = node.text
      end
      if (node['class'] == "active")
        current_page = node.text
      end
    end
  end
  
  title = ""
  doc.xpath("//title").each do |node|
    title += node.text
  end
  
  tokens = title.split(' - Read Online at Manga Stream')
  
  dir += tokens[0]
  
  puts "now saving the #{tokens[0]} chapter to #{dir}"
  puts "#{pageLinks.length} pages detected:"
  
  FileUtils.mkdir_p(dir);
  
  # legacy check 
  
  old_pages = doc.xpath("//div[@id='p']/a/img")
  
  if (old_pages.length > 0)
    puts "!page #{current_page} is a legacy page. saving..."
    old_pages.each do |node|
      puts "writing #{dir}/#{("%02d" % current_page)}#{File.extname(node['src'])}..."
      open(dir + "/" + ("%02d" % current_page) + File.extname(node['src']), 'wb') do |file|
        file << URI.parse(node['src']).read
      end
    end
  else
    
    doc.xpath("//style").each do |style|
      css_source += style.text
    end
    
    css = CssParser::Parser.new
    css.add_block!(css_source)
    
    css.each_rule_set do |rs|
      if (rs.selectors[0] == "#page")
        page_width = (rs['width'][0,rs['width'].length-3]).to_i
      end
    end
    
    doc.xpath("//div[@style]").each do |node|
      rs = CssParser::RuleSet.new(nil, node['style'])
      if (rs['z-index'].length > 0)
        page_part = {
          'z-index' => rs['z-index'][0,rs['z-index'].length-1],
          'width'=> rs['width'][0,rs['width'].length-3],
          'height' => rs['height'][0,rs['height'].length-3],
          'x' => rs['left'][0,rs['left'].length-3],
          'y' => rs['top'][0,rs['top'].length-3]
        }
        
        node.xpath(".//a/img").each do |link|
          page_part['image'] = link['src']
        end
        
        page_parts.push(page_part)
        
        page_surface += page_part['width'].to_i * page_part['height'].to_i
        
        puts "found an image part at x=#{page_part['x']} y=#{page_part['y']}"
      end
    end
    
    puts "total #{page_parts.length}"
    
    page_parts.sort! {|x,y| x['z-index'].to_i <=> y['z-index'].to_i}
    
    puts "now assembling page #{current_page}..."
    if (page_parts.length == 1) 
      puts "writing #{dir}/#{("%02d" % current_page)}#{File.extname(page_parts[0]['image'])}..."
      open(dir + "/" + ("%02d" % current_page) + File.extname(page_parts[0]['image']), 'wb') do |file|
        file << URI.parse(page_parts[0]['image']).read
      end
    else
      dst = Magick::Image.new(page_width, ((page_surface/page_width) + 1)) {self.background_color = Magick::Pixel.new(0, 0, 0, 0)}
      
      page_parts.each do |part|
        puts "adding #{part['selector']}..."
        buffer = URI.parse(part['image']).read
        img = Magick::Image.from_blob(buffer).first
        dst.composite!(img, part['x'].to_i, part['y'].to_i, Magick::OverCompositeOp)
      end
      
      puts "assembled"
      
      puts "writing #{dir}/#{("%02d" % current_page)}.png..."
      
      dst.trim!
      dst.write(dir + "/" + ("%02d" % current_page) + ".png")
    end
  end
  
  puts "done"
  
  pageLinks.each do |key, value|
    if (value != current_page)
      assembleMSPage(mangastream_root_url + key, value, dir)
    end
#    puts "#{key} is #{value}"
  end
  
  return ""
end

def assembleMSPage(url, page_num, dir)
  loaded_data = ""
  current_page = page_num
  css_source = ""
  page_width = 0
  page_parts = []
  page_surface = 0;
  
  loaded_data = URI.parse(url).read
  
  doc = Nokogiri::HTML.parse(loaded_data)
  
  # legacy check 
  
  old_pages = doc.xpath("//div[@id='p']/a/img")
  
  if (old_pages.length > 0)
    puts "!page #{current_page} is a legacy page. saving..."
    old_pages.each do |node|
      puts "writing #{dir}/#{("%02d" % current_page)}#{File.extname(node['src'])}..."
      open(dir + "/" + ("%02d" % current_page) + File.extname(node['src']), 'wb') do |file|
        file << URI.parse(node['src']).read
      end
    end
  else
    
    doc.xpath("//style").each do |style|
      css_source += style.text
    end
    
    css = CssParser::Parser.new
    css.add_block!(css_source)
    
    css.each_rule_set do |rs|
      if (rs.selectors[0] == "#page")
        page_width = (rs['width'][0,rs['width'].length-3]).to_i
      end
    end
    
    doc.xpath("//div[@style]").each do |node|
      rs = CssParser::RuleSet.new(nil, node['style'])
      if (rs['z-index'].length > 0)
        page_part = {
          'z-index' => rs['z-index'][0,rs['z-index'].length-1],
          'width'=> rs['width'][0,rs['width'].length-3],
          'height' => rs['height'][0,rs['height'].length-3],
          'x' => rs['left'][0,rs['left'].length-3],
          'y' => rs['top'][0,rs['top'].length-3]
        }
        
        node.xpath(".//a/img").each do |link|
          page_part['image'] = link['src']
        end
        
        page_parts.push(page_part)
        
        page_surface += page_part['width'].to_i * page_part['height'].to_i
        
        puts "found an image part at x=#{page_part['x']} y=#{page_part['y']}"
      end
    end
    
    puts "total #{page_parts.length}"
    
    page_parts.sort! {|x,y| x['z-index'].to_i <=> y['z-index'].to_i}
    
    puts "now assembling page #{current_page}..."
    if (page_parts.length == 1) 
      puts "writing #{dir}/#{("%02d" % current_page)}#{File.extname(page_parts[0]['image'])}..."
      open(dir + "/" + ("%02d" % current_page) + File.extname(page_parts[0]['image']), 'wb') do |file|
        file << URI.parse(page_parts[0]['image']).read
      end
    else
      dst = Magick::Image.new(page_width, ((page_surface/page_width) + 1)) {self.background_color = Magick::Pixel.new(0, 0, 0, 0)}
      
      page_parts.each do |part|
        puts "adding #{part['selector']}..."
        buffer = URI.parse(part['image']).read
        img = Magick::Image.from_blob(buffer).first
        dst.composite!(img, part['x'].to_i, part['y'].to_i, Magick::OverCompositeOp)
      end
      
      puts "assembled"
      
      puts "writing #{dir}/#{("%02d" % current_page)}.png..."
      
      dst.trim!
      dst.write(dir + "/" + ("%02d" % current_page) + ".png")
    end
  end
  
  puts "done"
end

if __FILE__ == $0
  # change this to save the chapters to a fixed folder
  dir = ""
  
  # parsing arguments
  if (ARGV.length > 0)
    if (ARGV[0] == "list") 
      load_mangastream_list
    elsif (ARGV[0] == "get")
      if (ARGV[1])
        load_mangastream_chapter(ARGV[1], dir)
      else
        puts "no chapter url provided"
      end
    else
#      puts "invalid arguments"
      load_mangastream_chapter(ARGV[0], dir)
    end
  else
    load_mangastream_list
  end

end