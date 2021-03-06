require 'byebug'
require 'active_support/inflector'

require 'active_support'
require 'active_support/core_ext'
require 'erb'

class ControllerBase
  attr_reader :req, :res, :params

  def initialize(req, res, route_params = {})
    @req                = req
    @res                = res
    @params             = Params.new(req, route_params)
    @authenticity_token = AuthenticityToken.new(req)

    if req.request_method != :get
      @authenticity_token.check_token(params)
    end

    Dir.glob("./app/helpers/*.rb").each do |helper_file|
      helper = helper_file.split('/')[-1][0..-4]
      helper = helper.classify.constantize
      extend(helper)
    end
  end

  def session
    @session ||= Session.new(req)
  end

  def flash
    @flash ||= Flash.new(req)
  end

  def form_authenticity_token
    @authenticity_token.token
  end

  def already_built_response?
    !!@already_built_response
  end

  def do_not_rebuild_response
    raise "Already built response" if already_built_response?
    @already_built_response = true
  end

  def render(template)
    controller = self.class.to_s.underscore
    template = File.read("./app/views/#{controller}/#{template}.html.erb")

    render_content(ERB.new(template).result(binding), "text/html")
  end

  def invoke_action(name)
    self.send(name)
    unless already_built_response?
      render name
    end
  end

  def redirect_to(url)
    do_not_rebuild_response

    res.status = 302
    res["location"] = url

    finish_response
  end

  def render_content(content, content_type)
    do_not_rebuild_response

    res.body = content
    res.content_type = content_type

    finish_response
  end

  def finish_response
    session.store_session(res)
    flash.store_flash(res)
    @authenticity_token.store_token(res)
  end
end
