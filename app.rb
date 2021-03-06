# Use the app.rb file to load Ruby code, modify or extend the models, or
# do whatever else you fancy when the theme is loaded.
#require 'ferret'
require 'net/http'

module Nesta
  SOCIAL = {
    "twitter" => "http://twitter.com/",
    "linkedin" => "http://linkedin.com/in/",
    "github" => "http://github.com/",
    "gittip" => "http://www.gittip.com/"
  }
  class Config
    @settings += %w[ exclude_from_search ]
    def self.exclude_from_search
      from_yaml("exclude_from_search") || [ "/", "/search" ]
    end
    SOCIAL.keys.each do |social|
      @settings += [ social ]
      self.send(:define_method, social.to_sym) do
        from_yaml(social) || false
      end
    end

    def self.bootstrap
      from_yaml("bootstrap") || "//netdna.bootstrapcdn.com/bootstrap/3.0.0/css/bootstrap.min.css"
    end

    def self.gravatar
      from_yaml("gravatar") || false
    end

    def self.cdn
      from_yaml("cdn_host") || ''
    end

    def self.domain
      from_yaml("domain") || ''
    end
  end

  class App
    before "/search" do
      @supress_disqus = true
    end

    before "/error/*" do
      @supress_disqus = true
    end

    # Uncomment the Rack::Static line below if your theme has assets
    # (i.e images or JavaScript).
    #
    # Put your assets in themes/bootstrap/public/bootstrap.
    #
    use Rack::Static, :urls => ["/bootstrap"], :root => "themes/bootstrap/public"

    not_found do
      haml :error
    end

    helpers do
      def show_disqus_comment_count?(page=nil)
        return false unless Nesta::Config.disqus_short_name
        return true  unless page
        return false unless (request.path == "/" || request.path.start_with?("/archive"))
        return !(page.abspath == "/" || page.abspath.include?("archive"))
      end

      def gitmd path
        uri = (path.start_with?("https://") ? URI.parse(path) : URI.parse("https://raw.github.com/jmervine/"+path))
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        body = http.request(Net::HTTP::Get.new(uri.request_uri)).body
        if path.end_with?(".md") || path.end_with?(".mdown")
          temp = Tilt['mdown'].new { body }
          return temp.render
        else
          return "<pre>#{body}</pre>"
        end
      end

      def active?(item)
        return request.path_info == item.abspath
      end

      def asset path
        return Nesta::Config.cdn + path
      end
    end

    # Add new routes here.
    # Handling legacy mervine.net routes.
    get '/:year/:month/:day/:path' do
      redirect "/#{params[:path].gsub("_","-")}"
    end

    get '/tags' do
      redirect "/categories"
    end

    get '/tag/:tag' do
      begin
        if Nesta::Page.find_by_path("/"+params[:tag])
          redirect "/"+params[:tag]
        else
          redirect "/categories"
        end
      rescue
        redirect "/categories"
      end
    end

    not_found do
      @supress_disqus = true
      set_common_variables
      @page = Nesta::Page.find_by_path('/error/400')
      @title = @page.title
      haml(@page.template, :layout => @page.layout)
    end unless Nesta::App.development?

    error do
      @supress_disqus = true
      set_common_variables
      @page = Nesta::Page.find_by_path('/error/500')
      @title = @page.title
      haml(@page.template, :layout => @page.layout)
    end unless Nesta::App.development?

  end
end
