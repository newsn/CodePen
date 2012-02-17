require 'net/http'
require 'haml'
require 'sass'
require 'compass'

NODE_URL = 'http://127.0.0.1:8124'

class PreProcessorService
  attr_accessor :errors
  
  def initialize()
    @errors = { }
  end
  
  def process_html(type, html)
    if type == 'jade'
      uri = URI(NODE_URL + '/jade/')
      res = Net::HTTP.post_form(uri, 'html' => html)
      html = res.body
    elsif type == 'haml'
      begin
        html = Haml::Engine.new(html).render
      rescue Exception => e
        @errors['HAML'] = e.message
      end
    end

    html
  end

  def process_css(type, css)
    begin
      if type == 'less'
        uri = URI(NODE_URL + '/less/')
        res = Net::HTTP.post_form(uri, 'css' => css)
        css = res.body
      elsif type == 'stylus'
        uri = URI(NODE_URL + '/stylus/')
        res = Net::HTTP.post_form(uri, 'css' => css)
        css = res.body
      elsif type == 'scss'
        begin
          # simple sass
          css = Sass::Engine.new(css, :syntax => :scss).render
        rescue Sass::SyntaxError => e
          @errors['SCSS'] = e.message
        end
      elsif type == 'sass'
        begin
          # compass with sass
          css = Sass::Engine.new(css, :syntax => :sass).render
        rescue Sass::SyntaxError => e
          @errors['SASS with Compass'] = e.message
        end
      end
    rescue
      puts 'Unable to process CSS: ' + "#{$!}"
    end
    
    css
  end
  
  def process_js(type, js)
    begin
      if type == 'coffeescript'
        uri = URI(NODE_URL + '/coffeescript/')
        res = Net::HTTP.post_form(uri, 'js' => js)
        js = res.body
      end
    rescue Exception => e
      puts 'Unable to process JS: ' + e.message
      @errors['Coffee Script'] = e.message
    end
    
    js
  end
  
end