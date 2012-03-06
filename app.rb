require 'sinatra'
require 'json'
require 'omniauth'
require 'omniauth-twitter'
require 'mongo_mapper'
require './services/gist_service'
require './models/user'
require './services/content_service'
require './services/preprocessor_service'
require './services/renderer'
require './lib/minify'
require 'awesome_print'

class App < Sinatra::Base
  # MongoMapper setup
  MongoMapper.database = 'tinkerbox'
  use Rack::Session::Cookie, :key => 'codepen'
  
  @@minify = false
  
  configure :production do
    @@minify = true
    disable :run, :reload, :show_exceptions
  end
  
  use OmniAuth::Builder do
    provider :twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET']
  end

  def set_session
    @user = User.get_by_session_id(session[:user_id])
    session[:user_id] = @user.uid
  end

  get '/sanity' do
    "working"
  end

  get '/' do
    set_session
    @c_data = { }
    @iframe_src = get_iframe_url request
    
    erb :index
  end
  
  # Returns the URL for the iframe
  # on localhost (for development) their is no subdomain.
  # This makes testing easier. On Production. we add a 'secure'
  # subdomain so that sneaky users can't XSS attack our home base.
  def get_iframe_url(request)
    domain = request.env['SERVER_NAME'] + ':' + request.env['SERVER_PORT']
    
    if Sinatra::Application.environment == :development
      return 'http://' + domain
    else
      return 'http://secure.' + domain
    end
  end
  
  get '/secure_iframe' do
    # Setting the x-frame-options headers allows the
    # content to be properly loaded in this iframe
    response.headers['X-Frame-Options'] = 'GOFORIT'
    
    erb :iframe
  end

  post '/save/content' do
    set_session
    service = ContentService.new
    result = service.save_content(@user.uid, params[:content])
    return result.to_json
  end

  get '/slugs' do

  end

  get '/content/:slug_name' do |name|
    set_session
    service = ContentService.new
    service.latest(name).to_json
  end

  get '/auth/:name/callback' do
    user_service = UserService.new
    user = user_service.first_or_new(request.env['omniauth.auth'])
    session[:user_id] = user._id
    redirect '/'
  end

  get '/auth/failure' do
    'Authentication Failed'
  end
  
  get '/logout' do
    session[:user_id] = false
    
    redirect '/'
  end
  
  get '/list/' do
    @pens = [ ]
    
    erb :list
  end

  post '/process/' do
    pps = PreProcessorService.new
    results = pps.process_content(params)
    
    if pps.errors.length > 0
      @errors = pps.errors
      results['error_html'] = erb :errors
    end
    
    encode(results)
  end

  def encode(obj)
    obj.to_json.gsub('/', '\/')
  end

  get '/:slug/fullpage/' do
    # todo, will need to actually pull
    # the right data for the url from data service
    data = get_data_by_slug()
    rend = Renderer.new(data)
    rend.render_full_page()
  end

  def get_data_by_slug
    return {
      'slug'       => 'CODE PEN',
      'html'        => '<h1>holy guac batman!</h1>',
      'css'         => 'body { background-color: blue; }',
      'js'          => 'console.log("testing");',

      'html_pre_processor' => 'none',
      'html_classes'       => 'en',

      'css_pre_processor' => 'none',
      'css_prefix_free'   => '',
      'css_starter'       => 'none',
      'css_external'      => '',

      'js_pre_processor' => 'none',
      'js_library'       => 'jquery-latest',
      'js_modernizr'     => '',
      'js_external'      => ''
    }
  end

  post '/gist/' do
    data = JSON.parse(params[:data])
    
    rend = Renderer.new()
    result = rend.render_full_page(data)
    
    gs = GistService.new
    url_to_gist = gs.create_gist(data, result)
    
    encode({ 'url' => url_to_gist })
  end
  
  helpers do
    def partial template
      erb template, :layout => false
    end
    def logged_in
      return session[:user_id]
    end
    def js_scripts(scripts, prod_filename)
      minify = Minify.new(@@minify, File.dirname(__FILE__))
      minify.script_tags(scripts, prod_filename)
    end
    def close embedded_json
      embedded_json.gsub('</', '<\/')
    end
  end
  
end
