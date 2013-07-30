#!/usr/bin/env ruby
#
#this script is made to download manga off mangastream.net website
#if no argument is supplied it prints the list of all available chapters with their links
#to download individual chapters use "mget {chapter_url}"
#
#!tip you can use any page in the chapter to get the full thing

require 'net/http'
require 'open-uri'
require 'rubygems'
require 'nokogiri'
require 'css_parser'
require 'fileutils'

def dir()
  # change this to save the chapters to a fixed folder
  return "/Users/d4rkie/tmp/"
end
  

def load_mangastream_list()
    
    loaded_data = ""
    mangastream_list_url = "http://mangastream.com"
    mangas = []
    
    loaded_data = URI.parse(mangastream_list_url).read
    
    doc = Nokogiri::HTML.parse(loaded_data)
    
    manga_title = {:name=>'', :chapters=>[]}
    
    doc.css(".new-list li a").each do |parent|
      chapter = {:url=>'', :name=>'', :date=>''}
      chapter[:url] = parent['href']

      name = ""
      text = ""
      number = 0
      title = ""

      parent.children.each do |node|
        if (node.name == "em")
          name = node.text
        elsif (node.name == "strong")
          number = node.text
        elsif (node.name == "text")
          text = node.text.chop!
        end
      end

      puts "#{text} #{number}: #{name} | #{parent['href']}"

      chapter[:name] = "#{parent.text}"
      mangas.push(chapter)
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
  last_page = 1

  loaded_data = URI.parse(url).read
  
  doc = Nokogiri::HTML.parse(loaded_data)
  
  tokens = url.split('/')

  current_page = tokens[-1]
  
  doc.xpath("//li/a").each do |node|
    if ((node['href'].include? tokens[-3]) && (node.text.include? 'Last Page'))
      last_page = node.text.match(/(\d+)/)
    end
  end

  (1..last_page[0].to_i).each do |i| 
    tokens[-1] = i
    pageLinks[tokens.join('/')] = i
  end
  
  title = ""
  doc.xpath("//title").each do |node|
    title += node.text
  end
  
  tokens = title.split(' - Manga Stream')
  
  dir += tokens[0]
  
  puts "now saving the #{tokens[0]} chapter to #{dir}"
  puts "#{pageLinks.length} pages detected:"
  
  FileUtils.mkdir_p(dir);
  
  old_pages = doc.xpath("//img[@id='manga-page']")
  
  if (old_pages.length > 0)
    puts "!page #{current_page} is a legacy page. saving..."
    old_pages.each do |node|
      puts "writing #{dir}/#{("%02d" % current_page)}#{File.extname(node['src'])}..."
      system("wget -c --output-document \"#{dir}/#{("%02d" % current_page)}#{File.extname(node['src'])}\" #{node['src']}")
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
      assembleMSPage(key, value, dir)
    end
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
  
  old_pages = doc.xpath("//img[@id='manga-page']")
  
  if (old_pages.length > 0)
    puts "!page #{current_page} is a legacy page. saving..."
    old_pages.each do |node|
      puts "writing #{dir}/#{("%02d" % current_page)}#{File.extname(node['src'])}..."
      system("wget -c --output-document \"#{dir}/#{("%02d" % current_page)}#{File.extname(node['src'])}\" #{node['src']}")
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

def download_all

  mangastream_root_url = "http://mangastream.com"

  mangas = load_mangastream_list

  mangas.each do |c|
      load_mangastream_chapter("#{c[:url]}", dir)
  end

end

def download_latest(num_chapters)

  mangas = load_mangastream_list

  num_chapters = (num_chapters && num_chapters.to_i > 0) ? num_chapters.to_i : 1;

  (0..(num_chapters-1)).each do |i| 
    load_mangastream_chapter("#{mangas[i][:url]}",dir)
  end

end

if __FILE__ == $0
  
  # parsing arguments
  if (ARGV.length > 0)
    if (ARGV[0] == "list") 
      load_mangastream_list
    elsif (ARGV[0] == "get")
      if (ARGV[1] == "all")
        download_all
      elsif (ARGV[1])
        load_mangastream_chapter(ARGV[1], dir)
      else
        puts "no chapter url provided"
      end
    elsif (ARGV[0] == "all")
        download_all
    elsif (ARGV[0] == "last")
        download_latest(ARGV[1])
    else
      load_mangastream_chapter(ARGV[0], dir)
    end
  else
    load_mangastream_list
  end

end
